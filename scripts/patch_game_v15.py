#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""patch_game_v15 — اتصال game.gd به نقشه بیک‌شده + اورهال بصری.
هر جایگزینی با assert تک‌موردی — اگر الگو پیدا نشد کل پچ شکست می‌خورد."""
import sys

P = "/home/z/my-project/game/scripts/game.gd"
src = open(P, encoding="utf-8").read()
n0 = src

def rep(old, new, cnt=1):
    global src
    c = src.count(old)
    if c != cnt:
        print("FAIL pattern (%d found):" % c, old[:90].replace("\n", "\\n"))
        sys.exit(1)
    src = src.replace(old, new)

# ── ۱) ثابت‌ها: WPS حذف، JSON ──
rep("""# پیست — حلقه‌ی شهری با گوشه‌های پخ (بسته)
const WPS := [
        Vector2(1215, 1215), Vector2(4320, 1215), Vector2(5130, 2025), Vector2(5130, 3645),
        Vector2(4320, 4455), Vector2(2025, 4455), Vector2(1215, 3645), Vector2(1215, 2025),
]
const WORLD_MIN := Vector2(360, 360)
const WORLD_MAX := Vector2(5980, 5300)""",
"""# پیست — از city_layout.json (بیک gen15_map.py) بارگذاری می‌شود
const LAYOUT_PATH := "res://data/city_layout.json"
var WORLD_MIN := Vector2(360, 360)
var WORLD_MAX := Vector2(5980, 5300)""")

# ── ۲) حذف پالت‌های مرده ──
rep("""const RIVAL_POOL := ["pride_blue", "pejo_green", "shahin", "shahin_white", "samand", "dena", "dena_race", "quick", "tiba", "formula_blue", "formula_red", "formula_black"]
const ROOF_COLS := [
        Color(0.085, 0.085, 0.125), Color(0.105, 0.095, 0.135), Color(0.075, 0.095, 0.115),
        Color(0.115, 0.09, 0.095), Color(0.09, 0.10, 0.105),
]
const PARK_COLS := [Color(0.16, 0.17, 0.21), Color(0.20, 0.16, 0.15), Color(0.14, 0.18, 0.19), Color(0.19, 0.19, 0.16)]
const NEON_COLS := [
        Color(0.25, 0.85, 1.0), Color(1.0, 0.55, 0.25), Color(1.0, 0.35, 0.55),
        Color(0.55, 1.0, 0.55), Color(1.0, 0.85, 0.3), Color(0.7, 0.5, 1.0),
]""",
"""const RIVAL_POOL := ["pride_blue", "pejo_green", "shahin", "shahin_white", "samand", "dena", "dena_race", "quick", "tiba", "formula_blue", "formula_red", "formula_black"]""")

# ── ۳) متغیرهای شهر ──
rep("""var buildings: Array = []  # {pos, rot, size, neon, wins, kind, roof, acs, neon2}
var lamps: Array = []      # {pos}
var trees: Array = []      # {pos, r}
var crosswalks: Array = [] # s روی مسیر
var manholes: Array = []   # {pos}
var patches: Array = []    # {pos, ang, w, h, lite}
var parked: Array = []     # {pos, rot, col}
var rumbles: Array = []    # {p0, p1} — لبه‌ی پیچ‌ها
var solids: Array = []     # {pos, r} — مانع استاتیک (درخت/تیر/پارک‌شده)""",
"""var buildings: Array = []  # {pos, rot, size} — از JSON
var solids: Array = []     # {pos, r} — درخت/تیر/پارک‌شده از JSON
var minimap: Control = null""")

# ── ۴) _build_track از JSON ──
rep("""func _build_track() -> void:
        var n := WPS.size()
        cum = [0.0]
        for i in n:
                var a: Vector2 = WPS[i]
                var b: Vector2 = WPS[(i + 1) % n]
                var d := (b - a)
                var l := d.length()
                seg_a.append(a)
                seg_d.append(d / l)
                seg_len.append(l)
                cum.append(cum[i] + l)
        track_len = cum[n]""",
"""func _build_track() -> void:
        var txt := FileAccess.get_file_as_string(LAYOUT_PATH)
        var j: Dictionary = JSON.parse_string(txt) if txt != "" else {}
        if j.is_empty() or j.get("centerline", []).size() < 8:
                push_error("city_layout.json missing!")
                get_tree().quit(1)
                return
        var meta: Dictionary = j["meta"]
        var r: Array = meta["rect"]
        map_rect = Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
        var wm: Array = meta.get("world_min", [360, 360])
        var wx: Array = meta.get("world_max", [5980, 5300])
        WORLD_MIN = Vector2(wm[0], wm[1])
        WORLD_MAX = Vector2(wx[0], wx[1])
        var pts: Array = j["centerline"]
        var n := pts.size()
        cum = [0.0]
        for i in n:
                var a: Vector2 = Vector2(pts[i][0], pts[i][1])
                var b: Vector2 = Vector2(pts[(i + 1) % n][0], pts[(i + 1) % n][1])
                var d := (b - a)
                var l := maxf(d.length(), 0.001)
                seg_a.append(a)
                seg_d.append(d / l)
                seg_len.append(l)
                cum.append(cum[i] + l)
        track_len = cum[n]""")

# ── ۵) _build_world — تایل‌ها + JSON ──
rep("""func _build_world() -> void:
        world = Node2D.new()
        add_child(world)
        var cm := CanvasModulate.new()
        cm.color = Color(0.82, 0.84, 1.0)
        world.add_child(cm)
        track_node = TrackNode.new()
        track_node.game = self
        world.add_child(track_node)
        neon_node = NeonNode.new()
        neon_node.game = self
        neon_node.z_index = 1
        world.add_child(neon_node)
        marks = SkidMarks.new()
        marks.z_index = 2
        world.add_child(marks)
        _gen_city()
        track_node.queue_redraw()
        neon_node.queue_redraw()""",
"""func _build_world() -> void:
        world = Node2D.new()
        add_child(world)
        var cm := CanvasModulate.new()
        cm.color = Color(0.93, 0.95, 1.0)
        world.add_child(cm)
        # نقشه‌ی شهر — ۴ تایل بیک‌شده (gen15_map) — کیفیت ۱:۱
        var tw := map_rect.size.x * 0.5
        var th := map_rect.size.y * 0.5
        for i in 4:
                var spr := Sprite2D.new()
                spr.texture = load("res://assets/sprites/map_%d.png" % i)
                spr.centered = false
                spr.position = map_rect.position + Vector2(float(i % 2) * tw, float(i / 2) * th)
                world.add_child(spr)
        marks = SkidMarks.new()
        marks.z_index = 2
        world.add_child(marks)
        _load_city()""")

# ── ۶) حذف _gen_city + کلاس‌های TrackNode/NeonNode ──
i0 = src.index("func _gen_city() -> void:")
i1 = src.index("## رد لاستیک — دریفت واقعی روی آسفالت می‌ماند")
src = src[:i0] + src[i1:]

# ── ۷) _load_city جدید (بعد از _nearest) ──
rep("""# ─────────────────────────── ساخت ماشین ───────────────────────────""",
"""func _load_city() -> void:
        var txt := FileAccess.get_file_as_string(LAYOUT_PATH)
        var j: Dictionary = JSON.parse_string(txt) if txt != "" else {}
        for b in j.get("buildings", []):
                buildings.append({
                        "pos": Vector2(b[0], b[1]),
                        "rot": deg_to_rad(float(b[2])),
                        "size": Vector2(b[3], b[4]),
                })
        for s in j.get("solids", []):
                solids.append({"pos": Vector2(s[0], s[1]), "r": float(s[2])})

# ─────────────────────────── ساخت ماشین ───────────────────────────""")

# ── ۸) مخروط نور واقعی به‌جای ذوزنقه ──
rep("""        var n := Node2D.new()
        var light := Polygon2D.new()
        light.polygon = PackedVector2Array([
                Vector2(30, -19), Vector2(30, 19), Vector2(400, 86), Vector2(400, -86),
        ])
        light.color = Color(1.0, 0.90, 0.60, light_alpha)
        var lmat := CanvasItemMaterial.new()
        lmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        light.material = lmat
        light.z_index = -1
        n.add_child(light)
        # هسته‌ی روشن نزدیک ماشین — حس نور واقعی نه مه
        var light2 := Polygon2D.new()
        light2.polygon = PackedVector2Array([
                Vector2(30, -13), Vector2(30, 13), Vector2(170, 34), Vector2(170, -34),
        ])
        light2.color = Color(1.0, 0.93, 0.68, light_alpha * 2.2)
        light2.material = lmat
        light2.z_index = -1
        n.add_child(light2)""",
"""        var n := Node2D.new()
        var lmat := CanvasItemMaterial.new()
        lmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        # مخروط نور جلو — بافت نرم (نه ذوزنقه‌ی تخت)
        var cone := Sprite2D.new()
        cone.texture = load("res://assets/sprites/headlight_cone.png")
        cone.centered = false
        cone.position = Vector2(52, -192)
        cone.scale = Vector2(1.15, 1.15)
        cone.material = lmat
        cone.modulate = Color(1.0, 0.96, 0.85, clampf(light_alpha * 6.5, 0.0, 0.85))
        cone.z_index = -1
        n.add_child(cone)""")

# ── ۹) اسپرایت بدون کشیدگی ──
rep("""        spr.scale = Vector2(1.5, 0.85) # نسبت واقعی خودرو — نه مربع اسباب‌بازی""",
"""        spr.scale = Vector2.ONE # اسپرایت نو نسبت ۲٫۳:۱ دارد""")

# ── ۱۰) شعله و دود با بافت ──
rep("""                var fg := Gradient.new()
                fg.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
                fg.colors = PackedColorArray([Color(1.0, 0.95, 0.55), Color(1.0, 0.45, 0.1), Color(0.6, 0.1, 0.05, 0.0)])
                fl.color_ramp = fg
                n.add_child(fl)""",
"""                fl.texture = load("res://assets/sprites/flame.png")
                var fg := Gradient.new()
                fg.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
                fg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.75, 0.85, 1.0, 0.8), Color(0.4, 0.5, 1.0, 0.0)])
                fl.color_ramp = fg
                fl.scale_amount_min = 0.55
                fl.scale_amount_max = 0.95
                n.add_child(fl)""")
rep("""                var sg := Gradient.new()
                sg.offsets = PackedFloat32Array([0.0, 1.0])
                sg.colors = PackedColorArray([Color(0.75, 0.75, 0.78, 0.5), Color(0.6, 0.6, 0.65, 0.0)])
                sm2.color_ramp = sg
                sm = sm2
                n.add_child(sm2)""",
"""                sm2.texture = load("res://assets/sprites/smoke.png")
                var sg := Gradient.new()
                sg.offsets = PackedFloat32Array([0.0, 1.0])
                sg.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(0.85, 0.85, 0.9, 0.0)])
                sm2.color_ramp = sg
                sm2.scale_amount_min = 0.6
                sm2.scale_amount_max = 1.15
                sm = sm2
                n.add_child(sm2)""")

# ── ۱۱) مقیاس رقیب/ترافیک + نور ترافیک ──
rep("""                fx["spr"].scale = Vector2(1.41, 0.80)""", """                fx["spr"].scale = Vector2.ONE""")
rep("""        var fx := _make_car_node(id, false, 0.0)""", """        var fx := _make_car_node(id, false, 0.035)""")
rep("""        fx["spr"].scale = Vector2(1.36, 0.78)""", """        fx["spr"].scale = Vector2.ONE""")

# ── ۱۲) سکه کمی بزرگ‌تر ──
rep("""                spr.scale = Vector2(0.42, 0.42)
                n.add_child(spr)""", """                spr.scale = Vector2(0.55, 0.55)
                n.add_child(spr)""")
rep("""                spr.scale = Vector2(0.42, 0.42) * (1.0 + 0.1 * sin(float(C["t"])))""",
"""                spr.scale = Vector2(0.55, 0.55) * (1.0 + 0.1 * sin(float(C["t"])))""")

# ── ۱۳) مینی‌مپ در HUD (بعد از pause btn) ──
rep("""        hud.add_child(pause_btn)
        _place(pause_btn, 0.0, 0.0, 0.0, 0.0, 24, 46, 116, 122)
        pause_btn.pressed.connect(_toggle_pause)""",
"""        hud.add_child(pause_btn)
        _place(pause_btn, 0.0, 0.0, 0.0, 0.0, 24, 46, 116, 122)
        pause_btn.pressed.connect(_toggle_pause)

        # مینی‌مپ — گوشه‌ی پایین-راست (سبک NFS)
        minimap = MiniMap.new()
        minimap.game = self
        minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _place(minimap, 1.0, 1.0, 1.0, 1.0, -268, -238, -20, -20)
        hud.add_child(minimap)""")

# ── ۱۴) گیج سرعت با تیک و ناحیه‌ی سرخ ──
rep("""        func _draw() -> void:
                var c := size * 0.5
                c.y = size.y * 0.86
                var r := minf(size.x * 0.46, size.y * 0.8)
                var a0 := PI * 0.78
                var a1 := PI * 2.22
                draw_arc(c, r, a0, a1, 40, Color(0.1, 0.1, 0.16, 0.75), 10.0, true)
                var ac := Color(0.25, 0.75, 1.0).lerp(Color(1.0, 0.35, 0.15), frac)
                if frac > 0.02:
                        draw_arc(c, r, a0, a0 + (a1 - a0) * frac, 40, ac, 10.0, true)
                var na := a0 + (a1 - a0) * frac
                var tip := c + Vector2(cos(na), sin(na)) * (r - 18.0)
                draw_line(c, tip, Color(0.95, 0.95, 1.0, 0.9), 4.0, true)
                draw_circle(c, 8.0, Color(0.85, 0.85, 0.95, 0.95))""",
"""        func _draw() -> void:
                var c := size * 0.5
                c.y = size.y * 0.86
                var r := minf(size.x * 0.46, size.y * 0.8)
                var a0 := PI * 0.78
                var a1 := PI * 2.22
                # ناحیه‌ی سرخ سرعت
                draw_arc(c, r, a0 + (a1 - a0) * 0.78, a1, 40, Color(0.75, 0.16, 0.12, 0.55), 11.0, true)
                draw_arc(c, r, a0, a1, 40, Color(0.08, 0.09, 0.14, 0.8), 11.0, true)
                # تیک‌ها
                for k in 11:
                        var ta := a0 + (a1 - a0) * k / 10.0
                        var p1 := c + Vector2(cos(ta), sin(ta)) * (r - 12.0)
                        var p2 := c + Vector2(cos(ta), sin(ta)) * (r - 22.0)
                        draw_line(p1, p2, Color(0.75, 0.78, 0.86, 0.5), 2.0, true)
                var ac := Color(0.55, 0.85, 1.0).lerp(Color(1.0, 0.32, 0.12), frac)
                if frac > 0.02:
                        draw_arc(c, r, a0, a0 + (a1 - a0) * frac, 40, ac, 7.0, true)
                var na := a0 + (a1 - a0) * frac
                var tip := c + Vector2(cos(na), sin(na)) * (r - 20.0)
                draw_line(c, tip, Color(0.97, 0.97, 1.0, 0.95), 4.0, true)
                draw_circle(c, 7.0, Color(0.88, 0.88, 0.96, 0.95))""")

# ── ۱۵) خطوط سرعت شعاعی ──
rep("""        func _draw() -> void:
                var rng := RandomNumberGenerator.new()
                rng.seed = int(t * 24.0)
                for i in 12:
                        var y := rng.randf_range(60.0, 660.0)
                        var edge := rng.randf() < 0.5
                        var x := rng.randf_range(-40.0, 240.0) if edge else rng.randf_range(1040.0, 1320.0)
                        var ln := rng.randf_range(60.0, 170.0)
                        var hdir := 1.0 if x < 500.0 else -1.0
                        draw_line(Vector2(x, y), Vector2(x + ln * hdir, y), Color(0.75, 0.88, 1.0, 0.09), 2.0)""",
"""        func _draw() -> void:
                var rng := RandomNumberGenerator.new()
                rng.seed = int(t * 30.0)
                var c := size * 0.5
                for i in 22:
                        var ang := rng.randf_range(0.0, TAU)
                        var r0 := rng.randf_range(430.0, 760.0)
                        var ln := rng.randf_range(90.0, 260.0)
                        var dirv := Vector2(cos(ang), sin(ang))
                        var p0 := c + dirv * r0
                        var p1 := c + dirv * (r0 + ln)
                        draw_line(p0, p1, Color(0.8, 0.9, 1.0, rng.randf_range(0.05, 0.14)), 2.5)""")

# ── ۱۶) کلاس مینی‌مپ (قبل از SteerHint) ──
rep("""## فلش‌های گوشه — جای متن «چپ/راست»، بدون یک کلمه""",
"""## مینی‌مپ — مسیر + جای ماشین‌ها (سبک NFS)
class MiniMap extends Control:
        var game: Node2D
        var acc := 0.0

        func _process(delta: float) -> void:
                acc += delta
                if acc > 0.08:
                        acc = 0.0
                        queue_redraw()

        func _draw() -> void:
                if game == null or game.seg_a.is_empty():
                        return
                var g := game
                var pad := 10.0
                var sw := size.x - pad * 2.0
                var sh := size.y - pad * 2.0
                var sc: float = minf(sw / g.map_rect.size.x, sh / g.map_rect.size.y)
                var off := (size - g.map_rect.size * sc) * 0.5
                draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.10, 0.72))
                draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0.85, 0.68, 0.28, 0.35), false, 1.5)
                var pts := PackedVector2Array()
                for i in range(0, g.seg_a.size(), 4):
                        pts.append(g.seg_a[i] * sc + off)
                if pts.size() > 2:
                        pts.append(pts[0])
                        draw_polyline(pts, Color(0.55, 0.60, 0.72, 0.9), 3.0, true)
                # خط پایان
                var st: Vector2 = g.seg_a[0] * sc + off
                draw_circle(st, 3.5, Color(0.95, 0.95, 1.0, 0.9))
                for R in g.rivals:
                        var rp: Vector2 = R["node"].position * sc + off
                        draw_circle(rp, 4.0, Color(0.95, 0.35, 0.30, 0.95))
                if g.car != null:
                        var pp: Vector2 = g.car.position * sc + off
                        draw_circle(pp, 5.0, Color(1.0, 0.82, 0.2, 1.0))
                        draw_circle(pp, 7.5, Color(1.0, 0.82, 0.2, 0.35))

## فلش‌های گوشه — جای متن «چپ/راست»، بدون یک کلمه""")

open(P, "w", encoding="utf-8").write(src)
print("game.gd patched OK —", len(n0), "->", len(src), "bytes")
