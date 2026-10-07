extends Node2D
## بوقی — مسابقه خیابانی شبانه از بالا (سبک کلاچ/NFS)
## نه بازی کودکانه، نه پرش روی مخروط — فرمان، دریفت، نیترو، ترافیک، رقیب.
## دوربین بالا؛ ماشین با فیزیک واقعی (گریپ لغزنده + دریفت دست‌برقه).

const VIEW_W := 1280.0
const VIEW_H := 720.0
const ROAD_W := 260.0
const LAPS := 2

# فیزیک ماشین
const ACC := 350.0
const BRK := 800.0
const TURN_RATE := 2.55
const GRIP := 9.0
const DRIFT_GRIP := 2.25
const NITRO_MULT := 1.40

# پیست — حلقه‌ی شهری با گوشه‌های پخ (بسته)
const WPS := [
        Vector2(1215, 1215), Vector2(4320, 1215), Vector2(5130, 2025), Vector2(5130, 3645),
        Vector2(4320, 4455), Vector2(2025, 4455), Vector2(1215, 3645), Vector2(1215, 2025),
]
const WORLD_MIN := Vector2(360, 360)
const WORLD_MAX := Vector2(5980, 5300)

const FA_D := "۰۱۲۳۴۵۶۷۸۹"
const RIVAL_POOL := ["pride_blue", "pejo_green", "shahin", "shahin_white", "samand", "dena", "dena_race", "quick", "tiba", "formula_blue", "formula_red", "formula_black"]
const ROOF_COLS := [
        Color(0.085, 0.085, 0.125), Color(0.105, 0.095, 0.135), Color(0.075, 0.095, 0.115),
        Color(0.115, 0.09, 0.095), Color(0.09, 0.10, 0.105),
]
const PARK_COLS := [Color(0.16, 0.17, 0.21), Color(0.20, 0.16, 0.15), Color(0.14, 0.18, 0.19), Color(0.19, 0.19, 0.16)]
const NEON_COLS := [
        Color(0.25, 0.85, 1.0), Color(1.0, 0.55, 0.25), Color(1.0, 0.35, 0.55),
        Color(0.55, 1.0, 0.55), Color(1.0, 0.85, 0.3), Color(0.7, 0.5, 1.0),
]

var lv: Dictionary
var elapsed := 0.0
var ended := false
var racing_over := false
var autotest := false
var autotest_full := false
var shots := false

# مسیر
var seg_a: Array = []      # نقطه شروع هر سگمنت
var seg_d: Array = []      # جهت هر سگمنت
var seg_len: Array = []
var cum: Array = []        # طول تجمعی
var track_len := 0.0
var buildings: Array = []  # {pos, rot, size, neon, wins, kind, roof, acs, neon2}
var lamps: Array = []      # {pos}
var trees: Array = []      # {pos, r}
var crosswalks: Array = [] # s روی مسیر
var manholes: Array = []   # {pos}
var patches: Array = []    # {pos, ang, w, h, lite}
var parked: Array = []     # {pos, rot, col}
var rumbles: Array = []    # {p0, p1} — لبه‌ی پیچ‌ها
var solids: Array = []     # {pos, r} — مانع استاتیک (درخت/تیر/پارک‌شده)

# بازیکن
var car_pos := Vector2.ZERO
var vel := Vector2.ZERO
var heading := 0.0
var path_s := 0.0          # تصویر موقعیت روی پیست
var lap := 0
var max_s := 620.0
var grip_norm := GRIP
var drifting := false
var nitro_on := false
var nitro_meter := 1.0
var nitro_drain := 0.30
var steer_left := false
var steer_right := false
var brake_held := false
var nitro_held := false
var steer_ptrs := {}       # شناسه‌ی لمس → ‎-1 چپ / ‎+1 راست (ضد گیرکردن فرمان)
var kb_left := false
var kb_right := false
var hint_l: Control
var hint_r: Control
var offroad := false
var invuln_until := 0.0
var bump_cd := 0.0
var coins_got := 0
var target_coins := -1
var time_left := 90.0
var shake := 0.0

# رقیب‌ها و ترافیک
var rivals: Array = []     # {node, spr, s, spd, pace, lane, lane_cur, ang, corner}
var traffic: Array = []    # {node, spr, s, dir, spd, lane}
var coins_on_road: Array = []  # {node, pos}
var finish_rank := 1

# نودها
var world: Node2D
var track_node: Node2D
var neon_node: Node2D
var marks: Node2D
var car: Node2D
var car_sprite: Sprite2D
var cam: Camera2D
var hud: CanvasLayer
var coin_label: Label
var time_label: Label
var mission_label: Label
var pos_label: Label
var lap_label: Label
var kmh_label: Label
var nitro_bar: ProgressBar
var progress: ProgressBar
var gauge: Control
var flame: CPUParticles2D
var smoke: CPUParticles2D
var lines: Control
var intro_label: Label
var pause_btn: Button
var pause_overlay: Control
var end_panel: PanelContainer
var end_title: Label
var end_stars: Label
var end_reward: Label
var end_retry_btn: Button
var end_menu_btn: Button
var brain = null
var car_anchor: Control
var _intro_stage := -1
var intro := 2.6
var _auto_timer := 0.0
var _at_stage := 0
var _at_heading0 := 0.0
var _spawn_coin_t := 0.0
var _spawn_traf_t := 0.4
var _mark_t := 0.0
var _drift_seen := false

const BRAIN_SCRIPT := preload("res://scripts/car_brain.gd")

func _ready() -> void:
        autotest = OS.get_cmdline_user_args().has("--autotest")
        autotest_full = OS.get_cmdline_user_args().has("--autotest-full")
        shots = OS.get_cmdline_user_args().has("--shots")
        if autotest_full and Globals.has_meta("at_retry"):
                print("[boghi][autotest] TAP-RETRY OK — بازی دوباره لود شد")
        var lid: int = Globals.get_meta("start_level", 1)
        if Globals.has_meta("custom_level"):
                lv = Globals.get_meta("custom_level")
                Globals.remove_meta("custom_level")
        else:
                lv = Globals.get_level(lid)
        if lv.is_empty():
                lv = {"id": 1, "type": "race", "name": "تست", "speed": 14.0, "distance": 500,
                        "time": 90, "obstacle_rate": 0.4, "coin_rate": 0.8, "ramp_rate": 0.3, "reward": 50}
        var stats: Dictionary = Globals.car_stats()
        max_s = 620.0 * clampf(float(stats["accel"]), 0.85, 1.45)
        grip_norm = GRIP * clampf(float(stats["jump"]), 0.8, 1.3)
        nitro_drain = 0.34 / maxf(0.8, float(stats["turbo"]))
        time_left = maxf(float(lv["time"]) * 1.5, 80.0)
        if lv["type"] == "collect":
                target_coins = int(lv.get("target_coins", 10))
        _build_track()
        _build_world()
        _build_car(stats)
        _build_hud()
        _spawn_rivals()
        AudioMgr.play_music()
        brain = BRAIN_SCRIPT.new()
        add_child(brain)
        car_anchor = Control.new()
        car_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
        car_anchor.size = Vector2.ZERO
        hud.add_child(car_anchor)
        mission_label.text = Globals.L("mission") + " " + fa(int(lv["id"])) + ": " + str(lv["name"])
        var mtw := create_tween()
        mtw.tween_interval(5.0)
        mtw.tween_property(mission_label, "modulate:a", 0.0, 0.8)
        if autotest or autotest_full or shots:
                time_left = 9999.0
        if autotest_full:
                _autotest_full()
        if shots:
                _run_shots()

# ─────────────────────────── ریاضی مسیر ───────────────────────────
func _build_track() -> void:
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
        track_len = cum[n]

func _path_pos(s: float) -> Vector2:
        var ss := fposmod(s, track_len)
        for i in seg_a.size():
                if ss <= cum[i + 1] + 0.001:
                        return seg_a[i] + seg_d[i] * (ss - cum[i])
        return seg_a[0]

func _path_dir(s: float) -> Vector2:
        var ss := fposmod(s, track_len)
        for i in seg_a.size():
                if ss <= cum[i + 1] + 0.001:
                        return seg_d[i]
        return seg_d[0]

## نزدیک‌ترین نقطه پیست + فاصله از آن (برای آفساید)
func _nearest(p: Vector2) -> Dictionary:
        var best_s := 0.0
        var best_d := INF
        for i in seg_a.size():
                var rel: Vector2 = p - seg_a[i]
                var t: float = clampf(rel.dot(seg_d[i]), 0.0, seg_len[i])
                var q: Vector2 = seg_a[i] + seg_d[i] * t
                var d := p.distance_to(q)
                if d < best_d:
                        best_d = d
                        best_s = cum[i] + t
        return {"s": best_s, "dist": best_d}

# ─────────────────────────── ساخت دنیا ───────────────────────────
func _build_world() -> void:
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
        neon_node.queue_redraw()

func _gen_city() -> void:
        var rng := RandomNumberGenerator.new()
        rng.seed = 20261013
        var step := 330.0
        for i in seg_a.size():
                var d: Vector2 = seg_d[i]
                var nrm := Vector2(-d.y, d.x)
                var s := 240.0
                var side := 1.0 if i % 2 == 0 else -1.0
                while s < seg_len[i] - 200.0:
                        var s_abs: float = cum[i] + s
                        if s_abs > 500.0 and s_abs < track_len - 500.0:
                                # ساختمان هم‌راستای شبکه‌ی شهر (کجی ناچیز) + فاصله‌ی تضمینی از جاده
                                var sz := Vector2(190.0 + rng.randf() * 160.0, 150.0 + rng.randf() * 140.0)
                                var hd := sz.length() * 0.5 + 18.0
                                var off: float = float(ROAD_W) * 0.5 + 40.0 + hd + rng.randf() * 120.0
                                var pos: Vector2 = seg_a[i] + d * s + nrm * off * side
                                var rot: float = rng.randf_range(-0.03, 0.03)
                                var neon: Color = NEON_COLS[rng.randi_range(0, NEON_COLS.size() - 1)]
                                # پنجره‌های ریز کم‌نور — پشت‌بام واقعی، نه بیلبورد
                                var wins: Array = []
                                var wcols := int(sz.x / 34.0)
                                var wrows := int(sz.y / 32.0)
                                for wy in wrows:
                                        for wx in wcols:
                                                if rng.randf() < 0.40:
                                                        var lp := Vector2(-sz.x * 0.5 + 18.0 + wx * 34.0, -sz.y * 0.5 + 16.0 + wy * 32.0)
                                                        wins.append(lp)
                                # جزئیات پشت‌بام — کولر و آب‌ریز
                                var acs: Array = []
                                for k in rng.randi_range(1, 3):
                                        acs.append(Vector2(rng.randf_range(-sz.x * 0.3, sz.x * 0.3), rng.randf_range(-sz.y * 0.3, sz.y * 0.3)))
                                buildings.append({
                                        "pos": pos, "rot": rot, "size": sz, "neon": neon, "wins": wins,
                                        "kind": rng.randi_range(0, 2),
                                        "roof": ROOF_COLS[rng.randi_range(0, ROOF_COLS.size() - 1)],
                                        "acs": acs, "neon2": NEON_COLS[rng.randi_range(0, NEON_COLS.size() - 1)],
                                })
                        s += step
                        side *= -1.0 if rng.randf() < 0.25 else 1.0
        # لبه‌های پیچ — آجر قرمز/سفید رالی
        for i in seg_a.size():
                var d1: Vector2 = seg_d[i]
                var d2: Vector2 = seg_d[(i + 1) % seg_a.size()]
                if absf(d1.angle_to(d2)) > 0.45:
                        for sg in [i, (i + 1) % seg_a.size()]:
                                var dd: Vector2 = seg_d[sg]
                                var nn := Vector2(-dd.y, dd.x)
                                var outer := 1.0 if nn.dot(-d1) < 0.0 else -1.0
                                # گوشه‌ی اتصال دو سگمنت: انتهای سگمنت قبلی + ابتدای بعدی
                                if sg == i:
                                        var p_end: Vector2 = seg_a[i] + seg_d[i] * seg_len[i]
                                        rumbles.append({"p0": p_end - seg_d[i] * 200.0 + nn * (ROAD_W * 0.5 + 6.0) * outer, "p1": p_end + nn * (ROAD_W * 0.5 + 6.0) * outer})
                                else:
                                        var p_st: Vector2 = seg_a[sg]
                                        rumbles.append({"p0": p_st + nn * (ROAD_W * 0.5 + 6.0) * outer, "p1": p_st + seg_d[sg] * 200.0 + nn * (ROAD_W * 0.5 + 6.0) * outer})
        # تیر چراغ خیابان — لبه‌ی آسفالت
        var ls := 0.0
        while ls < track_len:
                var dd: Vector2 = _path_dir(ls)
                var nn := Vector2(-dd.y, dd.x)
                var sgn := 1.0 if int(ls / 640.0) % 2 == 0 else -1.0
                lamps.append({"pos": _path_pos(ls) + nn * (ROAD_W * 0.5 + 12.0) * sgn})
                ls += 640.0
        # درخت‌ها — روی لبه‌ی بیرونی پیاده‌رو
        ls = 260.0
        var tside := 1.0
        while ls < track_len - 300.0:
                var dd: Vector2 = _path_dir(ls)
                var nn := Vector2(-dd.y, dd.x)
                trees.append({"pos": _path_pos(ls) + nn * (ROAD_W * 0.5 + 52.0) * tside, "r": 24.0 + rng.randf() * 12.0})
                tside *= -1.0
                ls += 470.0
        # گذرگاه عابر — هر ۱۵۰۰ متر یک‌بار
        ls = 900.0
        while ls < track_len - 700.0:
                crosswalks.append(ls)
                ls += 1500.0
        # منهول و وصله‌ی آسفالت — بافت خیابان واقعی
        ls = 430.0
        while ls < track_len - 400.0:
                var dd: Vector2 = _path_dir(ls)
                var nn := Vector2(-dd.y, dd.x)
                manholes.append({"pos": _path_pos(ls) + nn * rng.randf_range(-80.0, 80.0)})
                ls += 760.0
        ls = 280.0
        while ls < track_len - 300.0:
                var dd: Vector2 = _path_dir(ls)
                var nn := Vector2(-dd.y, dd.x)
                patches.append({
                        "pos": _path_pos(ls) + nn * rng.randf_range(-85.0, 85.0),
                        "ang": dd.angle() + rng.randf_range(-0.5, 0.5),
                        "w": 100.0 + rng.randf() * 100.0, "h": 42.0 + rng.randf() * 44.0,
                        "lite": rng.randf() < 0.4,
                })
                ls += 430.0
        # ماشین‌های پارک‌شده روی لبه‌ی پیاده‌رو (دور از گذرگاه و شروع)
        ls = 760.0
        var pside := 1.0
        while ls < track_len - 900.0:
                var ok := true
                for cw in crosswalks:
                        if absf(ls - float(cw)) < 260.0:
                                ok = false
                                break
                if ok:
                        var dd: Vector2 = _path_dir(ls)
                        var nn := Vector2(-dd.y, dd.x)
                        parked.append({
                                "pos": _path_pos(ls + 120.0) + nn * (ROAD_W * 0.5 + 26.0) * pside,
                                "rot": dd.angle(), "col": PARK_COLS[rng.randi_range(0, PARK_COLS.size() - 1)],
                        })
                pside *= -1.0
                ls += 1130.0
        # ⛔ فیکس «ماشین وسط جاده گیر می‌کند»: در گوشه‌ها، آفست عمودِ یک بازو
        # می‌افتد روی بازوی دیگر مسیر — مانع نزدیک به هر بازوی جاده حذف می‌شود
        # (فیلتر قبل از ساخت solids — وگرنه موانع قدیمی می‌مانند!)
        lamps = lamps.filter(func(L): return float(_nearest(L["pos"])["dist"]) > ROAD_W * 0.5 + 20.0)
        trees = trees.filter(func(T): return float(_nearest(T["pos"])["dist"]) > 66.0)
        parked = parked.filter(func(pk): return float(_nearest(pk["pos"])["dist"]) > 128.0)
        var keep: Array = []
        for b in buildings:
                var hd2: float = Vector2(b["size"]).length() * 0.5
                if float(_nearest(b["pos"])["dist"]) > hd2 + float(ROAD_W) * 0.5 + 26.0:
                        keep.append(b)
        buildings = keep
        # موانع استاتیک — درخت، تیر چراغ، ماشین پارک‌شده (برخورد واقعی)
        for T in trees:
                solids.append({"pos": T["pos"], "r": 20.0})
        for L in lamps:
                solids.append({"pos": L["pos"], "r": 8.0})
        for pk in parked:
                solids.append({"pos": pk["pos"], "r": 52.0})

## نود رسم پیست و شهر — استاتیک، یک‌بار رسم
class TrackNode extends Node2D:
        var game: Node2D

        func _draw() -> void:
                var g := game
                # ۱) زمین شب + بلوک‌های شهری (بافت پشت ساختمان‌ها)
                draw_rect(Rect2(Vector2(120, 120), Vector2(6400, 5700)), Color(0.040, 0.045, 0.075))
                var blk := RandomNumberGenerator.new()
                blk.seed = 777
                var bx := 160.0
                while bx < 6300.0:
                        var by := 160.0
                        while by < 5600.0:
                                draw_rect(Rect2(Vector2(bx, by), Vector2(300, 258)), Color(0.060, 0.064, 0.100))
                                by += 292.0
                        bx += 336.0
                # ۲) پیاده‌رو — باند یکپارچه‌ی صاف دور جاده (نه دایره‌های دندانه‌دار)
                for i in g.seg_a.size():
                        draw_line(g.seg_a[i], g.seg_a[i] + g.seg_d[i] * g.seg_len[i], Color(0.215, 0.225, 0.275), g.ROAD_W + 132.0, true)
                # ۳) آسفالت — هر سگمنت یک خط ضخیم (سرهای گرد گوشه‌ها را می‌بندد)
                for i in g.seg_a.size():
                        draw_line(g.seg_a[i], g.seg_a[i] + g.seg_d[i] * g.seg_len[i], Color(0.145, 0.145, 0.175), g.ROAD_W, true)
                # سایش لاستیک — دو نوار تیره‌ی لاین
                for i in g.seg_a.size():
                        var d: Vector2 = g.seg_d[i]
                        var nn := Vector2(-d.y, d.x) * 62.0
                        draw_line(g.seg_a[i] + nn, g.seg_a[i] + g.seg_d[i] * g.seg_len[i] + nn, Color(0.0, 0.0, 0.0, 0.10), 36.0, true)
                        draw_line(g.seg_a[i] - nn, g.seg_a[i] + g.seg_d[i] * g.seg_len[i] - nn, Color(0.0, 0.0, 0.0, 0.10), 36.0, true)
                # ۴) وصله‌ی آسفالت + منهول — روح خیابون
                for pa in g.patches:
                        draw_set_transform_matrix(Transform2D(pa["ang"], pa["pos"]))
                        var c := Color(0.175, 0.175, 0.205, 0.85) if bool(pa["lite"]) else Color(0.105, 0.105, 0.13, 0.85)
                        draw_rect(Rect2(-pa["w"] * 0.5, -pa["h"] * 0.5, pa["w"], pa["h"]), c)
                        draw_set_transform_matrix(Transform2D())
                for mh in g.manholes:
                        draw_circle(mh["pos"], 12.0, Color(0.095, 0.095, 0.115))
                        draw_arc(mh["pos"], 12.0, 0, TAU, 16, Color(0.16, 0.16, 0.19), 2.5, true)
                # ۵) خطوط جاده
                for i in g.seg_a.size():
                        var d: Vector2 = g.seg_d[i]
                        var nn := Vector2(-d.y, d.x)
                        # لبه‌های سفید
                        var eo := nn * (float(g.ROAD_W) * 0.5 - 14.0)
                        draw_line(g.seg_a[i] + eo, g.seg_a[i] + g.seg_d[i] * g.seg_len[i] + eo, Color(0.88, 0.89, 0.94, 0.50), 5.0, true)
                        draw_line(g.seg_a[i] - eo, g.seg_a[i] + g.seg_d[i] * g.seg_len[i] - eo, Color(0.88, 0.89, 0.94, 0.50), 5.0, true)
                        # دوخط زرد وسط (خیابان دوطرفه)
                        var co := nn * 5.0
                        draw_line(g.seg_a[i] + co, g.seg_a[i] + g.seg_d[i] * g.seg_len[i] + co, Color(0.95, 0.78, 0.25, 0.55), 4.0, true)
                        draw_line(g.seg_a[i] - co, g.seg_a[i] + g.seg_d[i] * g.seg_len[i] - co, Color(0.95, 0.78, 0.25, 0.55), 4.0, true)
                # خط‌چین لاین‌های داخلی
                var ss := 0.0
                while ss < g.track_len:
                        var a: Vector2 = g._path_pos(ss)
                        var dd: Vector2 = g._path_dir(ss)
                        var nn := Vector2(-dd.y, dd.x)
                        draw_line(a + nn * 62.0, a + nn * 62.0 + dd * 56.0, Color(0.92, 0.92, 0.95, 0.28), 4.0, true)
                        draw_line(a - nn * 62.0, a - nn * 62.0 + dd * 56.0, Color(0.92, 0.92, 0.95, 0.28), 4.0, true)
                        ss += 128.0
                # ۶) گذرگاه عابر
                for cw in g.crosswalks:
                        var base: Vector2 = g._path_pos(float(cw))
                        var dd: Vector2 = g._path_dir(float(cw))
                        var nn := Vector2(-dd.y, dd.x)
                        var off := -float(g.ROAD_W) * 0.5 + 26.0
                        while off < float(g.ROAD_W) * 0.5 - 26.0:
                                draw_line(base + nn * off, base + dd * 30.0 + nn * off, Color(0.92, 0.93, 0.96, 0.30), 17.0, true)
                                off += 44.0
                # ۷) آجر قرمز/سفید لبه‌ی پیچ‌ها
                for rb in g.rumbles:
                        var p0: Vector2 = rb["p0"]
                        var p1: Vector2 = rb["p1"]
                        var ln := p0.distance_to(p1)
                        var dir := (p1 - p0) / maxf(ln, 1.0)
                        var t := 0.0
                        var k := 0
                        while t < ln:
                                var seg := minf(30.0, ln - t)
                                draw_line(p0 + dir * t, p0 + dir * (t + seg), Color(0.85, 0.22, 0.16, 0.9) if k % 2 == 0 else Color(0.92, 0.92, 0.94, 0.9), 9.0, true)
                                t += seg
                                k += 1
                # ۸) خط شروع/پایان — شطرنجی + گرید
                var st: Vector2 = g._path_pos(0.0)
                var sd: Vector2 = g._path_dir(0.0)
                var sn := Vector2(-sd.y, sd.x)
                for row in 2:
                        for c in 8:
                                var cell := 30.0
                                var p: Vector2 = st + sn * (-float(g.ROAD_W) * 0.5 + c * 32.5 + 4.0) + sd * (row * cell)
                                var col := Color(0.92, 0.92, 0.92, 0.85) if (row + c) % 2 == 0 else Color(0.08, 0.08, 0.1, 0.85)
                                var poly := PackedVector2Array([
                                        p, p + sn * 30.0, p + sn * 30.0 + sd * cell, p + sd * cell,
                                ])
                                draw_colored_polygon(poly, col)
                for gi in 2:
                        var goff: Vector2 = sn * (-70.0 if gi == 0 else 70.0)
                        var gp0: Vector2 = st + goff - sd * 130.0
                        var gpts := PackedVector2Array([gp0, gp0 + sd * 110.0, gp0 + sd * 110.0 + sn * 52.0, gp0 + sn * 52.0, gp0])
                        draw_polyline(gpts, Color(0.92, 0.92, 0.95, 0.30), 3.0, true)
                # ۹) درخت‌ها
                for T in g.trees:
                        var r: float = T["r"]
                        draw_circle(T["pos"], r, Color(0.075, 0.135, 0.085))
                        draw_circle(T["pos"] + Vector2(-r * 0.22, -r * 0.24), r * 0.62, Color(0.105, 0.185, 0.115))
                        draw_circle(T["pos"] + Vector2(r * 0.18, r * 0.2), r * 0.30, Color(0.06, 0.105, 0.07))
                # ۱۰) ماشین‌های پارک‌شده
                for pk in g.parked:
                        draw_set_transform_matrix(Transform2D(pk["rot"], pk["pos"]))
                        draw_rect(Rect2(-44, -20, 88, 40), pk["col"])
                        draw_rect(Rect2(-14, -16, 40, 32), Color(0.10, 0.115, 0.15))
                        draw_rect(Rect2(-44, -20, 88, 40), Color(0.0, 0.0, 0.0, 0.45), false, 2.0)
                        draw_set_transform_matrix(Transform2D())
                # ۱۱) ساختمان‌های شبانه — پشت‌بام، کولر، پنجره‌ی دوتایی
                for b in g.buildings:
                        var sz: Vector2 = b["size"]
                        draw_set_transform_matrix(Transform2D(b["rot"], b["pos"]))
                        draw_rect(Rect2(-sz * 0.5 - Vector2(7, 7), sz + Vector2(14, 14)), Color(0.015, 0.015, 0.04, 0.6))
                        draw_rect(Rect2(-sz * 0.5, sz), b["roof"])
                        draw_rect(Rect2(-sz * 0.5, sz), Color(0.30, 0.33, 0.44, 0.32), false, 2.0)
                        for ap in b["acs"]:
                                draw_rect(Rect2(ap - Vector2(13, 11), Vector2(26, 22)), Color(0.06, 0.062, 0.09))
                                draw_arc(ap, 7.0, 0, TAU, 10, Color(0.13, 0.135, 0.17), 2.0, true)
                        var nc: Color = b["neon"]
                        var nc2: Color = b["neon2"]
                        for wi in b["wins"].size():
                                var lp: Vector2 = b["wins"][wi]
                                var wc: Color = Color(1.0, 0.90, 0.68) if wi % 4 != 0 else (nc if wi % 8 == 0 else nc2)
                                wc.a = 0.24
                                draw_rect(Rect2(lp - Vector2(6, 4.5), Vector2(12, 9)), wc)
                        # تابلوی نئون پشت‌بام برای برخی
                        if int(b["kind"]) == 1:
                                draw_rect(Rect2(-sz.x * 0.5 + 12, -sz.y * 0.5 + 10, minf(88.0, sz.x - 24.0), 13), Color(nc.r, nc.g, nc.b, 0.75))
                        draw_set_transform_matrix(Transform2D())

## هاله‌های نئون — همه‌چیز درخشان در یک نود ADD
class NeonNode extends Node2D:
        var game: Node2D

        func _draw() -> void:
                var g := game
                # استخر نور چراغ‌های خیابان روی آسفالت
                for L in g.lamps:
                        var lp: Vector2 = L["pos"]
                        draw_circle(lp, 95.0, Color(1.0, 0.80, 0.45, 0.045))
                        draw_circle(lp, 50.0, Color(1.0, 0.85, 0.55, 0.075))
                        draw_circle(lp, 5.0, Color(1.0, 0.93, 0.7, 0.85))
                # هاله‌ی پنجره‌ها + نئون پشت‌بام + تابلو
                for b in g.buildings:
                        var sz: Vector2 = b["size"]
                        draw_set_transform_matrix(Transform2D(b["rot"], b["pos"]))
                        var nc: Color = b["neon"]
                        for wi in b["wins"].size():
                                var lp: Vector2 = b["wins"][wi]
                                var wc: Color = Color(1.0, 0.90, 0.68) if wi % 4 != 0 else (nc if wi % 8 == 0 else b["neon2"])
                                wc.a = 0.035
                                draw_rect(Rect2(lp - Vector2(11, 8), Vector2(22, 16)), wc)
                        if int(b["kind"]) == 0:
                                # نوار نئون باریک دور پشت‌بام
                                var r := Rect2(-sz * 0.5 + Vector2(4, 4), sz - Vector2(8, 8))
                                var c := Rect2(r.position, Vector2(r.size.x, 2.0))
                                var c2 := Rect2(Vector2(r.position.x, r.end.y - 2.0), Vector2(r.size.x, 2.0))
                                var c3 := Rect2(r.position, Vector2(2.0, r.size.y))
                                var c4 := Rect2(Vector2(r.end.x - 2.0, r.position.y), Vector2(2.0, r.size.y))
                                for rc in [c, c2, c3, c4]:
                                        draw_rect(rc, Color(nc.r, nc.g, nc.b, 0.34))
                        if int(b["kind"]) == 1:
                                var bw := minf(88.0, sz.x - 24.0)
                                draw_rect(Rect2(-sz.x * 0.5 + 6, -sz.y * 0.5 + 4, bw + 12, 25), Color(nc.r, nc.g, nc.b, 0.20))
                        draw_set_transform_matrix(Transform2D())
                # مهتابی خط شروع
                var st: Vector2 = g._path_pos(0.0)
                var sd: Vector2 = g._path_dir(0.0)
                var sn := Vector2(-sd.y, sd.x)
                draw_line(st + sn * (float(g.ROAD_W) * 0.5 + 20.0), st - sn * (float(g.ROAD_W) * 0.5 + 20.0), Color(0.55, 0.85, 1.0, 0.10), 70.0, true)

## رد لاستیک — دریفت واقعی روی آسفالت می‌ماند
class SkidMarks extends Node2D:
        var segs: Array = []  # {pos, ang}
        var MAX := 520

        func add(p: Vector2, ang: float) -> void:
                segs.append({"pos": p, "ang": ang})
                if segs.size() > MAX:
                        segs.pop_front()
                queue_redraw()

        func _draw() -> void:
                for s in segs:
                        draw_set_transform_matrix(Transform2D(s["ang"], s["pos"]))
                        draw_rect(Rect2(-11, -3, 22, 6), Color(0.03, 0.03, 0.05, 0.5))
                draw_set_transform_matrix(Transform2D())

# ─────────────────────────── ساخت ماشین ───────────────────────────
func _car_tex_path(id: String) -> String:
        var top := "res://assets/sprites/" + id + "_top.png"
        if ResourceLoader.exists(top):
                return top
        # ⛔ هرگز اسپرایت کناری (چشم‌دار) از بالا نشان داده نمی‌شود — جایگزین: بوقی
        return "res://assets/sprites/boghi_top.png"

func _make_car_node(id: String, with_fx: bool, light_alpha: float) -> Dictionary:
        var n := Node2D.new()
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
        n.add_child(light2)
        var sh := Sprite2D.new()
        sh.texture = _make_shadow_tex()
        sh.scale = Vector2(1.45, 0.85)
        sh.modulate = Color(1, 1, 1, 0.55)
        sh.z_index = -1
        n.add_child(sh)
        var spr := Sprite2D.new()
        spr.texture = load(_car_tex_path(id))
        spr.scale = Vector2(1.5, 0.85) # نسبت واقعی خودرو — نه مربع اسباب‌بازی
        n.add_child(spr)
        # آندرگلوی نئون — امضای شبانه‌ی NFS زیر هر ماشین
        var ug := Polygon2D.new()
        ug.polygon = _ellipse_pts(Vector2(0, 8), Vector2(88, 32))
        var uh := 0.0
        for ch in id:
                uh = fmod(uh + float(ch.unicode_at(0)) * 0.113, 1.0)
        ug.color = Color.from_hsv(uh, 0.85, 1.0, 0.34)
        var ugmat := CanvasItemMaterial.new()
        ugmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        ug.material = ugmat
        ug.z_index = -1
        n.add_child(ug)
        var fl: CPUParticles2D = null
        var sm: CPUParticles2D = null
        if with_fx:
                fl = CPUParticles2D.new()
                fl.position = Vector2(-95, 0)
                fl.emitting = false
                fl.amount = 26
                fl.lifetime = 0.3
                fl.direction = Vector2(-1, 0)
                fl.spread = 12.0
                fl.initial_velocity_min = 240.0
                fl.initial_velocity_max = 420.0
                fl.scale_amount_min = 3.0
                fl.scale_amount_max = 6.5
                var fg := Gradient.new()
                fg.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
                fg.colors = PackedColorArray([Color(1.0, 0.95, 0.55), Color(1.0, 0.45, 0.1), Color(0.6, 0.1, 0.05, 0.0)])
                fl.color_ramp = fg
                n.add_child(fl)
                var sm2 := CPUParticles2D.new()
                sm2.position = Vector2(-84, 24)
                sm2.emitting = false
                sm2.amount = 20
                sm2.lifetime = 0.8
                sm2.direction = Vector2(0, 0)
                sm2.spread = 180.0
                sm2.initial_velocity_min = 30.0
                sm2.initial_velocity_max = 90.0
                sm2.scale_amount_min = 4.0
                sm2.scale_amount_max = 9.0
                var sg := Gradient.new()
                sg.offsets = PackedFloat32Array([0.0, 1.0])
                sg.colors = PackedColorArray([Color(0.75, 0.75, 0.78, 0.5), Color(0.6, 0.6, 0.65, 0.0)])
                sm2.color_ramp = sg
                sm = sm2
                n.add_child(sm2)
        return {"node": n, "spr": spr, "flame": fl, "smoke": sm}

func _build_car(stats: Dictionary) -> void:
        car = Node2D.new()
        car.z_index = 5
        var fx := _make_car_node(str(Globals.CARS[Globals.selected_car]["id"]), true, 0.10)
        car.add_child(fx["node"])
        world.add_child(car)
        car_sprite = fx["spr"]
        flame = fx["flame"]
        smoke = fx["smoke"]
        car_pos = _path_pos(0.0)
        heading = _path_dir(0.0).angle()
        car.position = car_pos
        car.rotation = heading
        cam = Camera2D.new()
        cam.zoom = Vector2(1.02, 1.02)
        add_child(cam)
        # ⛔ فیکس «ماشین را ندیدم»: دوربین از همان فریم اول پشت ماشین است، نه مبدأ دنیا
        cam.position = car_pos + _path_dir(0.0) * 180.0
        cam.make_current()

func _spawn_rivals() -> void:
        var pool := RIVAL_POOL.duplicate()
        pool.shuffle()
        var starts := [90.0, 180.0, 270.0]
        var lanes := [-58.0, 58.0, -58.0]
        for i in 3:
                var id: String = pool[i]
                var fx := _make_car_node(id, false, 0.055)
                world.add_child(fx["node"])
                fx["node"].z_index = 4
                fx["spr"].scale = Vector2(1.41, 0.80)
                rivals.append({
                        "node": fx["node"], "spr": fx["spr"],
                        "s": float(starts[i]), "spd": 0.0,
                        "pace": randf_range(0.965, 1.045),
                        "lane": float(lanes[i]), "lane_cur": float(lanes[i]),
                        "ang": 0.0, "corner": false, "mt": 0.0,
                })

func _spawn_traffic(s_abs: float) -> void:
        var ids := ["traf_white", "traf_gray", "traf_taxi", "traf_van"]
        var id: String = ids[randi_range(0, ids.size() - 1)]
        var fx := _make_car_node(id, false, 0.0)
        world.add_child(fx["node"])
        fx["node"].z_index = 3
        fx["spr"].scale = Vector2(1.36, 0.78)
        var dir := 1.0
        if randf() < 0.22:
                dir = -1.0
        var lane := 58.0 * dir
        traffic.append({
                "node": fx["node"], "spr": fx["spr"],
                "s": s_abs, "dir": dir, "spd": randf_range(150.0, 250.0), "lane": lane,
        })

func _spawn_coins(s_abs: float) -> void:
        var side := 1.0 if randf() < 0.5 else -1.0
        var lane := 60.0 * side
        var dd: Vector2 = _path_dir(s_abs)
        var nn := Vector2(-dd.y, dd.x)
        for i in 4:
                var tex: Texture2D = load("res://assets/sprites/coin.png")
                var n := Node2D.new()
                n.z_index = 2
                var spr := Sprite2D.new()
                spr.texture = tex
                spr.scale = Vector2(0.42, 0.42)
                n.add_child(spr)
                var pos: Vector2 = _path_pos(s_abs + i * 115.0) + nn * lane
                n.position = pos
                world.add_child(n)
                coins_on_road.append({"node": n, "pos": pos, "s": s_abs + float(i) * 95.0, "t": randf() * TAU})

func _ellipse_pts(c: Vector2, r: Vector2) -> PackedVector2Array:
        var pts := PackedVector2Array()
        for i in 24:
                var a := TAU * float(i) / 24.0
                pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
        return pts

func _make_shadow_tex() -> ImageTexture:
        var sz := Vector2i(150, 90)
        var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
        var cx := sz.x / 2.0
        var cy := sz.y / 2.0
        for y in sz.y:
                for x in sz.x:
                        var d := Vector2((x - cx) / (cx - 5.0), (y - cy) / (cy - 5.0)).length()
                        var a: float = clamp(1.0 - d, 0.0, 1.0)
                        img.set_pixel(x, y, Color(0.0, 0.0, 0.02, a * a * 0.85))
        return ImageTexture.create_from_image(img)

# ─────────────────────────── HUD مسابقه ───────────────────────────
func _build_hud() -> void:
        hud = CanvasLayer.new()
        hud.process_mode = Node.PROCESS_MODE_ALWAYS
        add_child(hud)
        var font: FontFile = load("res://assets/fonts/Lalezar-Regular.ttf")
        var bold: FontFile = load("res://assets/fonts/Vazirmatn-Bold.ttf")

        # فرمان لمسی = سراسری (در _unhandled_input) — دیگر هیچ زون‌گیر‌کردنی وجود ندارد.
        # راهنمای بصری گوشه‌ها — فقط وقتی واقعاً می‌فرمانی روشن می‌شوند
        hint_l = SteerHint.new()
        hint_l.game = self
        hint_l.dir = -1
        hint_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _place(hint_l, 0.0, 1.0, 0.0, 1.0, 36, -150, 156, -30)
        hud.add_child(hint_l)
        hint_r = SteerHint.new()
        hint_r.game = self
        hint_r.dir = 1
        hint_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _place(hint_r, 1.0, 1.0, 1.0, 1.0, -156, -150, -36, -30)
        hud.add_child(hint_r)

        # جایگاه — بالای وسط، بزرگ و طلایی (NFS)
        pos_label = _hud_label(font, 58, Vector2.ZERO, Color(0.98, 0.8, 0.2))
        pos_label.add_theme_constant_override("outline_size", 12)
        _place(pos_label, 0.5, 0.0, 0.5, 0.0, -160, 44, 160, 116)
        pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        lap_label = _hud_label(font, 30, Vector2.ZERO, Color(0.95, 0.95, 0.98, 0.9))
        _place(lap_label, 0.5, 0.0, 0.5, 0.0, -160, 112, 160, 152)
        lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

        # نوار پیشرفت کل مسابقه
        progress = ProgressBar.new()
        progress.min_value = 0
        progress.max_value = 100
        progress.value = 0
        progress.show_percentage = false
        progress.add_theme_stylebox_override("background", _sb(Color(0.08, 0.08, 0.12, 0.8), Color(0.5, 0.45, 0.3, 0.6), 6, 1, false))
        progress.add_theme_stylebox_override("fill", _sb(Color(0.95, 0.62, 0.12), Color(0.7, 0.4, 0.05), 6, 0, false))
        progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hud.add_child(progress)
        _place(progress, 0.5, 0.0, 0.5, 0.0, -140, 154, 140, 170)

        coin_label = _hud_label(font, 34, Vector2.ZERO, Color(0.95, 0.75, 0.1))
        _place(coin_label, 1.0, 0.0, 1.0, 0.0, -280, 46, -70, 96)
        time_label = _hud_label(font, 32, Vector2.ZERO, Color(0.95, 0.4, 0.3))
        _place(time_label, 1.0, 0.0, 1.0, 0.0, -280, 100, -70, 144)
        mission_label = _hud_label(font, 26, Vector2.ZERO, Color(0.9, 0.9, 0.95, 0.85))
        _place(mission_label, 0.0, 0.0, 1.0, 0.0, 130, 46, -20, 86)
        mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

        # دکمه توقف — بالا چپ
        pause_btn = Button.new()
        pause_btn.text = "II"
        pause_btn.add_theme_font_override("font", font)
        pause_btn.add_theme_font_size_override("font_size", 34)
        _style_btn(pause_btn, false)
        hud.add_child(pause_btn)
        _place(pause_btn, 0.0, 0.0, 0.0, 0.0, 24, 46, 116, 122)
        pause_btn.pressed.connect(_toggle_pause)

        # نیترو — دکمه بزرگ آبی، بالا-وسطِ زون راست (انگشت راست راحت می‌رسد)
        var btn_nitro := Button.new()
        btn_nitro.text = Globals.L("nitro")
        btn_nitro.add_theme_font_override("font", font)
        btn_nitro.add_theme_font_size_override("font_size", 44)
        var nfs := _sb(Color(0.13, 0.35, 0.75), Color(0.35, 0.6, 1.0), 18, 3)
        btn_nitro.add_theme_stylebox_override("normal", nfs)
        btn_nitro.add_theme_stylebox_override("hover", _sb(Color(0.18, 0.42, 0.85), Color(0.45, 0.7, 1.0), 18, 3))
        btn_nitro.add_theme_stylebox_override("pressed", _sb(Color(0.1, 0.25, 0.55), Color(0.35, 0.6, 1.0), 18, 3))
        btn_nitro.add_theme_stylebox_override("disabled", nfs)
        btn_nitro.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
        btn_nitro.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
        btn_nitro.button_down.connect(func(): nitro_held = true)
        btn_nitro.button_up.connect(func(): nitro_held = false)
        hud.add_child(btn_nitro)
        _place(btn_nitro, 1.0, 1.0, 1.0, 1.0, -500, -190, -260, -50)

        # ترمز — دکمه قرمز تیره بالا-وسطِ زون چپ
        var btn_brake := Button.new()
        btn_brake.text = "ترمز"
        btn_brake.add_theme_font_override("font", font)
        btn_brake.add_theme_font_size_override("font_size", 38)
        btn_brake.add_theme_stylebox_override("normal", _sb(Color(0.45, 0.13, 0.13), Color(0.75, 0.3, 0.25), 18, 3))
        btn_brake.add_theme_stylebox_override("hover", _sb(Color(0.55, 0.18, 0.16), Color(0.8, 0.35, 0.3), 18, 3))
        btn_brake.add_theme_stylebox_override("pressed", _sb(Color(0.32, 0.08, 0.08), Color(0.75, 0.3, 0.25), 18, 3))
        btn_brake.add_theme_stylebox_override("disabled", _sb(Color(0.45, 0.13, 0.13), Color(0.75, 0.3, 0.25), 18, 3))
        btn_brake.add_theme_color_override("font_color", Color(1.0, 0.9, 0.85))
        btn_brake.button_down.connect(func(): brake_held = true)
        btn_brake.button_up.connect(func(): brake_held = false)
        hud.add_child(btn_brake)
        _place(btn_brake, 0.0, 1.0, 0.0, 1.0, 260, -190, 500, -50)

        # گیج نیترو — باریک، بالای گیج سرعت
        nitro_bar = ProgressBar.new()
        nitro_bar.min_value = 0
        nitro_bar.max_value = 100
        nitro_bar.value = 100
        nitro_bar.show_percentage = false
        nitro_bar.add_theme_stylebox_override("background", _sb(Color(0.07, 0.08, 0.14, 0.85), Color(0.3, 0.5, 0.9, 0.7), 6, 1, false))
        nitro_bar.add_theme_stylebox_override("fill", _sb(Color(0.25, 0.65, 1.0), Color(0.15, 0.4, 0.9), 6, 0, false))
        nitro_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hud.add_child(nitro_bar)
        _place(nitro_bar, 0.5, 1.0, 0.5, 1.0, -130, -252, 130, -228)

        # گیج سرعت — سفارشی (قوس + عقربه) + عدد کیلومتر
        gauge = SpeedGauge.new()
        gauge.game = self
        gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _place(gauge, 0.5, 1.0, 0.5, 1.0, -125, -185, 125, -35)
        hud.add_child(gauge)
        kmh_label = _hud_label(font, 56, Vector2.ZERO, Color(0.98, 0.98, 1.0))
        kmh_label.add_theme_constant_override("outline_size", 10)
        kmh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _place(kmh_label, 0.5, 1.0, 0.5, 1.0, -85, -150, 85, -85)

        # خطوط سرعت نیترو
        lines = SpeedLines.new()
        lines.size = Vector2(VIEW_W, VIEW_H)
        lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
        lines.visible = false
        hud.add_child(lines)

        # شمارش معکوس
        intro_label = Label.new()
        intro_label.add_theme_font_override("font", font)
        intro_label.add_theme_font_size_override("font_size", 130)
        intro_label.add_theme_color_override("font_color", Color(0.98, 0.8, 0.2))
        intro_label.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
        intro_label.add_theme_constant_override("outline_size", 24)
        intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        intro_label.anchor_left = 0.0
        intro_label.anchor_right = 1.0
        intro_label.anchor_top = 0.26
        intro_label.anchor_bottom = 0.26
        intro_label.offset_top = -90.0
        intro_label.offset_bottom = 100.0
        intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        intro_label.z_index = 30
        hud.add_child(intro_label)

        # پرده توقف
        pause_overlay = Control.new()
        pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        pause_overlay.visible = false
        var pv := ColorRect.new()
        pv.color = Color(0, 0, 0, 0.6)
        pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
        pause_overlay.add_child(pv)
        var pl := Label.new()
        pl.text = Globals.L("paused")
        pl.add_theme_font_override("font", bold)
        pl.add_theme_font_size_override("font_size", 46)
        pl.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
        pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        pl.anchor_left = 0.0
        pl.anchor_right = 1.0
        pl.anchor_top = 0.45
        pl.anchor_bottom = 0.55
        pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        pause_overlay.add_child(pl)
        hud.add_child(pause_overlay)

func _hud_label(font: FontFile, size: int, pos: Vector2, col: Color) -> Label:
        var l := Label.new()
        l.add_theme_font_override("font", font)
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", col)
        l.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.1))
        l.add_theme_constant_override("outline_size", 8)
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hud.add_child(l)
        return l

func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
        c.anchor_left = al
        c.anchor_top = at
        c.anchor_right = ar
        c.anchor_bottom = ab
        c.offset_left = ol
        c.offset_top = ot
        c.offset_right = orr
        c.offset_bottom = ob

func _sb(bg: Color, border: Color, radius: int, bw: int = 0, shadow := true) -> StyleBoxFlat:
        var sb := StyleBoxFlat.new()
        sb.bg_color = bg
        sb.set_corner_radius_all(radius)
        sb.border_color = border
        sb.border_width_left = bw
        sb.border_width_right = bw
        sb.border_width_top = bw
        sb.border_width_bottom = bw + (4 if bw > 0 else 0)
        if shadow:
                sb.shadow_color = Color(0, 0, 0, 0.35)
                sb.shadow_size = 6
        return sb

func _style_btn(b: Button, primary := true) -> void:
        var base := Color(0.16, 0.42, 0.60) if primary else Color(0.16, 0.17, 0.24)
        var dark := Color(0.10, 0.28, 0.42) if primary else Color(0.35, 0.38, 0.5)
        b.add_theme_stylebox_override("normal", _sb(base, dark, 16, 2))
        b.add_theme_stylebox_override("hover", _sb(base.lightened(0.08), dark, 16, 2))
        b.add_theme_stylebox_override("pressed", _sb(dark, dark, 16, 2))
        b.add_theme_stylebox_override("disabled", _sb(Color(0.2, 0.2, 0.26), Color(0.4, 0.4, 0.5), 16, 2))
        var fg := Color(0.96, 0.97, 1.0)
        b.add_theme_color_override("font_color", fg)
        b.add_theme_color_override("font_hover_color", fg)
        b.add_theme_color_override("font_focus_color", fg)
        b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
        b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.62))

## گیج سرعت — قوس + عقربه، حس داشبورد
class SpeedGauge extends Control:
        var game: Node2D
        var frac := 0.0

        func _process(_delta: float) -> void:
                if game == null:
                        return
                var tgt: float = clampf(absf(game.vel.length()) / (game.max_s * 1.45), 0.0, 1.0)
                frac = lerpf(frac, tgt, _delta * 8.0)
                queue_redraw()

        func _draw() -> void:
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
                draw_circle(c, 8.0, Color(0.85, 0.85, 0.95, 0.95))

## خطوط سرعت نیترو
class SpeedLines extends Control:
        var t := 0.0

        func _process(delta: float) -> void:
                t += delta
                if visible:
                        queue_redraw()

        func _draw() -> void:
                var rng := RandomNumberGenerator.new()
                rng.seed = int(t * 24.0)
                for i in 12:
                        var y := rng.randf_range(60.0, 660.0)
                        var edge := rng.randf() < 0.5
                        var x := rng.randf_range(-40.0, 240.0) if edge else rng.randf_range(1040.0, 1320.0)
                        var ln := rng.randf_range(60.0, 170.0)
                        var hdir := 1.0 if x < 500.0 else -1.0
                        draw_line(Vector2(x, y), Vector2(x + ln * hdir, y), Color(0.75, 0.88, 1.0, 0.09), 2.0)

# ─────────────────────────── ورودی ───────────────────────────
## فرمان لمسی ضدباگ: هر انگشت با شناسه‌اش ثبت می‌شود؛ رهاکردن در هر نقطه‌ای
## یا کشیدن انگشت از یک نیمه به نیمه‌ی دیگر همیشه درست کار می‌کند.
func _side_of(pos: Vector2) -> int:
        return -1 if pos.x < VIEW_W * 0.5 else 1

func _unhandled_input(e: InputEvent) -> void:
        if e is InputEventScreenTouch:
                if e.pressed and e.position.y > VIEW_H * 0.24:
                        steer_ptrs[e.index] = _side_of(e.position)
                elif not e.pressed:
                        steer_ptrs.erase(e.index)
        elif e is InputEventScreenDrag:
                if steer_ptrs.has(e.index):
                        steer_ptrs[e.index] = _side_of(e.position)
        elif e is InputEventMouseButton:
                if e.button_index == MOUSE_BUTTON_LEFT:
                        if e.pressed and e.position.y > VIEW_H * 0.24:
                                steer_ptrs[2001] = _side_of(e.position)
                        elif not e.pressed:
                                steer_ptrs.erase(2001)
        if e is InputEventKey and e.pressed:
                if e.keycode == KEY_LEFT or e.keycode == KEY_A:
                        kb_left = true
                elif e.keycode == KEY_RIGHT or e.keycode == KEY_D:
                        kb_right = true
                elif e.keycode == KEY_DOWN or e.keycode == KEY_S:
                        brake_held = true
                elif e.keycode == KEY_SPACE or e.keycode == KEY_X or e.keycode == KEY_UP:
                        nitro_held = true
        if e is InputEventKey and not e.pressed:
                if e.keycode == KEY_LEFT or e.keycode == KEY_A:
                        kb_left = false
                elif e.keycode == KEY_RIGHT or e.keycode == KEY_D:
                        kb_right = false
                elif e.keycode == KEY_DOWN or e.keycode == KEY_S:
                        brake_held = false
                elif e.keycode == KEY_SPACE or e.keycode == KEY_X or e.keycode == KEY_UP:
                        nitro_held = false

## مشتق نهایی فرمان — هر فریم قبل از فیزیک
func _derive_steer() -> void:
        var pl := kb_left
        var pr := kb_right
        for v in steer_ptrs.values():
                if int(v) < 0:
                        pl = true
                else:
                        pr = true
        steer_left = pl
        steer_right = pr
        if hint_l != null:
                hint_l.amt = lerpf(float(hint_l.amt), 1.0 if steer_left else 0.0, 0.25)
                hint_l.queue_redraw()
        if hint_r != null:
                hint_r.amt = lerpf(float(hint_r.amt), 1.0 if steer_right else 0.0, 0.25)
                hint_r.queue_redraw()

## فلش‌های گوشه — جای متن «چپ/راست»، بدون یک کلمه
class SteerHint extends Control:
        var game: Node2D
        var dir := -1
        var amt := 0.0

        func _draw() -> void:
                if amt < 0.02:
                        return
                var c := size * 0.5
                var col := Color(1.0, 0.95, 0.75, 0.30 * amt)
                for k in 3:
                        var x := c.x + float(dir) * (k - 1) * 26.0
                        draw_polyline(PackedVector2Array([
                                Vector2(x + float(dir) * 14.0, c.y - 22.0),
                                Vector2(x - float(dir) * 14.0, c.y),
                                Vector2(x + float(dir) * 14.0, c.y + 22.0),
                        ]), col, 7.0, true)

func _toggle_pause() -> void:
        if ended and not racing_over:
                return
        var t := get_tree()
        t.paused = not t.paused
        if pause_overlay != null:
                pause_overlay.visible = t.paused
        AudioMgr.set_engine(not t.paused, 0.3)
        AudioMgr.set_skid(false)

# ─────────────────────────── حلقه اصلی ───────────────────────────
func _process(delta: float) -> void:
        if get_tree().paused:
                return
        elapsed += delta

        # شمارش معکوس — موتور زنده است، دنیا نفس نگه می‌دارد
        if intro > 0.0 and not racing_over:
                intro -= delta
                var stage := int((2.6 - maxf(intro, 0.0)) / 0.65)
                if stage != _intro_stage and stage <= 4:
                        _intro_stage = stage
                        if stage < 3:
                                intro_label.text = fa(3 - stage)
                                AudioMgr.play_sfx("beep")
                        else:
                                intro_label.text = Globals.L("go")
                                AudioMgr.play_sfx("horn")
                                intro_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5))
                                cam.zoom = Vector2(1.18, 1.18)
                        intro_label.pivot_offset = Vector2(get_viewport_rect().size.x * 0.5, 95.0)
                        intro_label.scale = Vector2(1.6, 1.6)
                        intro_label.modulate.a = 1.0
                        var itw := create_tween()
                        itw.tween_property(intro_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
                        itw.parallel().tween_property(intro_label, "modulate:a", 0.0, 0.4).set_delay(0.25)
                if intro <= 0.0:
                        intro_label.visible = false
                AudioMgr.set_engine(true, clampf(0.85 - intro * 0.3, 0.15, 0.85))
                cam.zoom = cam.zoom.lerp(Vector2(1.05, 1.05), delta * 2.0)
                _update_rivals(delta)
                return

        if autotest:
                _run_autotest(delta)

        _derive_steer()
        _update_player(delta)
        _update_rivals(delta)
        _update_traffic(delta)
        _update_coins(delta)
        _update_hud(delta)
        _update_camera(delta)
        _update_brain_anchor()

        if shake > 0.0:
                shake = maxf(0.0, shake - delta * 26.0)
                cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
        else:
                cam.offset = Vector2.ZERO

# ─────────────────────────── فیزیک بازیکن ───────────────────────────
func _update_player(delta: float) -> void:
        if racing_over:
                # بعد خط پایان — ماشین آروم می‌ایستد، دنیا زنده می‌ماند
                vel *= exp(-1.6 * delta)
                car_pos += vel * delta
                car.position = car_pos
                AudioMgr.set_engine(false)
                AudioMgr.set_skid(false)
                return

        var fwd := Vector2.RIGHT.rotated(heading)
        var vf := vel.dot(fwd)
        var vl := vel - fwd * vf

        # فرمان
        var steer := 0.0
        if steer_left:
                steer -= 1.0
        if steer_right:
                steer += 1.0
        var sn := clampf(vf / max_s, -1.0, 1.0)

        # دریفت: ترمز + فرمان در سرعت، یا پیچ تند نزدیک سرعت ماکزیمم
        var want_drift := (brake_held and absf(vf) > 250.0 and absf(steer) > 0.2) \
                or (absf(steer) > 0.85 and absf(vf) > 0.78 * max_s)
        if want_drift != drifting:
                drifting = want_drift
                if drifting:
                        AudioMgr.set_skid(true, 0.7)

        # نیترو
        nitro_on = nitro_held and nitro_meter > 0.02 and not brake_held
        if nitro_on:
                nitro_meter = maxf(0.0, nitro_meter - nitro_drain * delta)
                if not lines.visible:
                        AudioMgr.play_sfx("nitro")
        else:
                nitro_meter = minf(1.0, nitro_meter + delta * (0.10 if drifting else 0.012))

        # شتاب خودکار (کلاچی: گاز خودشه) — ترمز کاربر برنده است
        var target := max_s * (NITRO_MULT if nitro_on else 1.0)
        if brake_held and not drifting:
                vf = move_toward(vf, 0.0, BRK * delta)
        else:
                var acc := ACC * (2.2 if nitro_on else 1.0)
                vf = move_toward(vf, target, acc * delta)

        # آفساید — چمن/بلوک شهری کند می‌کند
        var nr := _nearest(car_pos)
        offroad = nr["dist"] > ROAD_W * 0.5 - 6.0
        var near_road: bool = nr["dist"] < ROAD_W * 0.5 + 60.0
        if offroad:
                vf *= exp(-1.9 * delta)
                shake = maxf(shake, 1.6)

        # چرخش — سرعت‌محور؛ در دریفت فرمان بازتر
        var turn := TURN_RATE * sn * (1.35 if drifting else 1.0)
        heading += steer * turn * delta

        # گریپ جانبی — قلب دریفت (ارتقای لاستیک = گریپ بیشتر)
        var grip := DRIFT_GRIP if drifting else grip_norm
        vl *= exp(-grip * delta)
        vel = fwd * vf + vl
        car_pos += vel * delta

        # برخورد با ساختمان‌ها
        _resolve_buildings()

        # محدوده دنیا
        var clamped := Vector2(
                clampf(car_pos.x, WORLD_MIN.x, WORLD_MAX.x),
                clampf(car_pos.y, WORLD_MIN.y, WORLD_MAX.y))
        if clamped != car_pos:
                car_pos = clamped
                vel *= 0.5

        # برخورد با ترافیک و رقیب‌ها
        _car_contacts(delta)

        # مسافت روی پیست + دور — فقط نزدیک جاده حساب می‌شود (ضد پرش کاذب)
        var new_s: float = nr["s"]
        var prev := path_s
        path_s = new_s
        if near_road:
                if prev > track_len * 0.85 and path_s < track_len * 0.15 and vf > 0.0:
                        lap += 1
                        if lap < LAPS:
                                AudioMgr.play_sfx("lap")
                        else:
                                _cross_finish()
                elif prev < track_len * 0.15 and path_s > track_len * 0.85 and vf < 0.0:
                        lap -= 1

        # رد لاستیک + دود دریفت
        if drifting and absf(vf) > 120.0:
                _mark_t -= delta
                if _mark_t <= 0.0:
                        _mark_t = 0.024
                        var back := car_pos - fwd * 80.0
                        var nrm := Vector2(-fwd.y, fwd.x)
                        marks.add(back + nrm * 26.0, heading)
                        marks.add(back - nrm * 26.0, heading)
        if smoke != null:
                smoke.emitting = drifting and absf(vf) > 140.0
        # جیغ لاستیک متناسب با لغزش
        var slip := (DRIFT_GRIP if drifting else grip_norm)
        var skid_amt := clampf(1.0 - (grip / grip_norm) + (vl.length() / 240.0), 0.0, 1.0)
        AudioMgr.set_skid(drifting and absf(vf) > 100.0, skid_amt)

        # صدا + افکت
        AudioMgr.set_engine(true, clampf(absf(vf) / max_s, 0.12, 1.0) * (1.12 if nitro_on else 1.0))
        if flame != null:
                flame.emitting = nitro_on
        if lines != null:
                lines.visible = nitro_on

        # اعمال به نود
        car.position = car_pos
        car.rotation = heading
        # لِن ضربه‌ای
        if elapsed < invuln_until:
                car_sprite.modulate = Color(1.0, 0.6, 0.55, 0.9)
        else:
                car_sprite.modulate = Color(1, 1, 1)

func _resolve_buildings() -> void:
        for b in buildings:
                var sz: Vector2 = b["size"]
                var loc: Vector2 = (car_pos - b["pos"]).rotated(-float(b["rot"]))
                var hx := sz.x * 0.5 + 20.0
                var hy := sz.y * 0.5 + 20.0
                if absf(loc.x) < hx and absf(loc.y) < hy:
                        var px := hx - absf(loc.x)
                        var py := hy - absf(loc.y)
                        var push := Vector2.ZERO
                        if px < py:
                                push = Vector2(signf(loc.x) * px, 0)
                        else:
                                push = Vector2(0, signf(loc.y) * py)
                        car_pos += push.rotated(float(b["rot"]))
                        if elapsed > bump_cd:
                                bump_cd = elapsed + 0.5
                                vel *= 0.42
                                shake = 7.0
                                AudioMgr.play_sfx("crash")
        # موانع استاتیک — درخت/تیر چراغ/ماشین پارک‌شده (برخورد دایره‌ای نرم)
        for so in solids:
                var dv: Vector2 = car_pos - so["pos"]
                var d := dv.length()
                var rr: float = float(so["r"]) + 24.0
                if d < rr and d > 0.01:
                        car_pos += dv.normalized() * (rr - d)
                        if elapsed > bump_cd:
                                bump_cd = elapsed + 0.5
                                vel *= 0.55
                                shake = maxf(shake, 4.0)
                                AudioMgr.play_sfx("clank")

func _car_contacts(_delta: float) -> void:
        for R in rivals:
                var rp: Vector2 = R["node"].position
                var d := car_pos.distance_to(rp)
                if d < 76.0 and d > 0.01:
                        var push := (car_pos - rp).normalized() * (76.0 - d) * 0.6
                        car_pos += push
                        vel *= 0.985
        for i in traffic.size():
                var T = traffic[i]
                var tp: Vector2 = T["node"].position
                if car_pos.distance_to(tp) < 74.0 and elapsed > invuln_until:
                        invuln_until = elapsed + 1.1
                        vel *= 0.34
                        shake = 10.0
                        AudioMgr.play_sfx("crash")
                        T["spd"] *= 0.4
                        T["lane"] += (30.0 if T["lane"] > 0 else -30.0)

func _cross_finish() -> void:
        if racing_over:
                return
        racing_over = true
        finish_rank = _calc_rank()
        if not ended:
                ended = true
                var stars := clampi(4 - finish_rank, 0, 3)
                var win := finish_rank <= 2
                var reward := 0
                if win:
                        var bonus: int = [60, 25, 10, 0][finish_rank - 1]
                        reward = int(lv["reward"]) + stars * 25 + bonus
                        Globals.add_coins(reward)
                        Globals.set_stars(int(lv["id"]), stars)
                        AudioMgr.play_sfx("win")
                else:
                        AudioMgr.play_sfx("fail")
                _celebrate(win)
                var w := win
                var s := stars
                var r := reward
                get_tree().create_timer(2.6).timeout.connect(func(): _show_end(w, s, r))

func _calc_rank() -> int:
        var my_prog := float(lap) * track_len + path_s
        var rank := 1
        for R in rivals:
                if float(R["s"]) > my_prog:
                        rank += 1
        return rank

# ─────────────────────────── رقیب‌ها ───────────────────────────
func _update_rivals(delta: float) -> void:
        var racing := not racing_over and intro <= 0.0
        for R in rivals:
                var s: float = R["s"]
                if racing:
                        # سرعت پایه + کش‌وسان: عقب بماند جانی می‌گیرد
                        var base := max_s * float(R["pace"])
                        var my_prog := float(lap) * track_len + path_s
                        var gap := my_prog - s
                        if gap > 600.0:
                                base *= 1.15
                        elif gap < -500.0:
                                base *= 0.9
                        # پیچ — از قبل کند می‌کند
                        var d1 := _path_dir(s + 90.0)
                        var d2 := _path_dir(s + 300.0)
                        var ang := absf(d1.angle_to(d2))
                        var cs := 1.0 - clampf(ang * 0.62, 0.0, 0.44)
                        R["corner"] = ang > 0.3
                        R["spd"] = lerpf(float(R["spd"]), base * cs, delta * 2.0)
                        s += float(R["spd"]) * delta
                        R["s"] = s
                        # لاین — نرم تغییر می‌کند
                        R["lane_cur"] = lerpf(float(R["lane_cur"]), float(R["lane"]), delta * 1.2)
                var dd := _path_dir(s)
                var nn := Vector2(-dd.y, dd.x)
                var pos := _path_pos(s) + nn * float(R["lane_cur"])
                R["node"].position = pos
                var ta := dd.angle()
                R["node"].rotation = lerp_angle(float(R["node"].rotation), ta, delta * 6.0)
                R["ang"] = absf(dd.angle_to(Vector2.RIGHT.rotated(float(R["node"].rotation))))
                # رد لاستیک رقیب در پیچ تند — تایمر مستقل خودش (باگ اشتراک _mark_t)
                if racing and bool(R["corner"]) and float(R["spd"]) > 300.0:
                        R["mt"] = float(R["mt"]) - delta * 0.5
                        if float(R["mt"]) <= 0.0:
                                R["mt"] = 0.024
                                var back := pos - dd * 74.0
                                marks.add(back + nn * 24.0, ta)
                                marks.add(back - nn * 24.0, ta)
        if pos_label != null:
                var rk := _calc_rank() if not racing_over else finish_rank
                pos_label.text = fa(rk) + "/" + fa(rivals.size() + 1)
        if lap_label != null:
                var shown := mini(lap + 1, LAPS)
                lap_label.text = "دور " + fa(shown) + "/" + fa(LAPS)

# ─────────────────────────── ترافیک ───────────────────────────
func _update_traffic(delta: float) -> void:
        var racing := not racing_over and intro <= 0.0
        _spawn_traf_t -= delta
        if racing and _spawn_traf_t <= 0.0 and traffic.size() < 7:
                _spawn_traf_t = randf_range(0.9, 1.6)
                var my_prog := float(lap) * track_len + path_s
                _spawn_traffic(my_prog + randf_range(1100.0, 2400.0))
        for i in range(traffic.size() - 1, -1, -1):
                var T = traffic[i]
                if racing:
                        T["s"] += float(T["dir"]) * float(T["spd"]) * delta
                var my_prog2 := float(lap) * track_len + path_s
                if absf(float(T["s"]) - my_prog2) > 2800.0:
                        T["node"].queue_free()
                        traffic.remove_at(i)
                        continue
                var ss: float = fposmod(float(T["s"]), track_len)
                var dd := _path_dir(ss) * float(T["dir"])
                var nn := Vector2(-dd.y, dd.x)
                T["node"].position = _path_pos(ss) + nn * float(T["lane"])
                T["node"].rotation = dd.angle()

func _update_coins(delta: float) -> void:
        var racing := not racing_over and intro <= 0.0
        _spawn_coin_t -= delta
        if racing and _spawn_coin_t <= 0.0 and coins_on_road.size() < 24:
                _spawn_coin_t = randf_range(1.5, 2.3)
                var my_prog := float(lap) * track_len + path_s
                _spawn_coins(my_prog + randf_range(900.0, 2000.0))
        for i in range(coins_on_road.size() - 1, -1, -1):
                var C = coins_on_road[i]
                C["t"] = float(C["t"]) + delta * 5.0
                var spr: Sprite2D = C["node"].get_child(0)
                spr.scale = Vector2(0.42, 0.42) * (1.0 + 0.1 * sin(float(C["t"])))
                var my_prog2 := float(lap) * track_len + path_s
                if absf(fposmod(float(C["s"]), track_len) - fposmod(my_prog2, track_len)) > 2400.0:
                        C["node"].queue_free()
                        coins_on_road.remove_at(i)
                        continue
                if racing and car_pos.distance_to(C["pos"]) < 64.0:
                        coins_got += 1
                        nitro_meter = minf(1.0, nitro_meter + 0.05)
                        AudioMgr.play_sfx("coin")
                        C["node"].queue_free()
                        coins_on_road.remove_at(i)

# ─────────────────────────── HUD و دوربین ───────────────────────────
func _update_hud(delta: float) -> void:
        coin_label.text = "سکه " + fa(coins_got) + ((" / " + fa(target_coins)) if target_coins > 0 else "")
        if time_left < 900.0:
                time_left -= delta
                time_label.text = "زمان " + fa(maxi(0, int(ceil(time_left))))
                if time_left <= 0.0 and not racing_over:
                        racing_over = true
                        ended = true
                        AudioMgr.set_engine(false)
                        AudioMgr.play_sfx("fail")
                        _celebrate(false)
                        get_tree().create_timer(1.4).timeout.connect(func(): _show_end(false, 0, 0))
        else:
                time_label.text = ""
        var total := float(lap) * track_len + path_s
        progress.value = 100.0 * clampf(total / (float(LAPS) * track_len), 0.0, 1.0)
        nitro_bar.value = nitro_meter * 100.0
        var vf := absf(vel.dot(Vector2.RIGHT.rotated(heading)))
        kmh_label.text = fa(int(vf * 0.21))

func _update_camera(delta: float) -> void:
        # دوربین جلوی ماشین (سبک کلاچ): ماشین پایین کادر می‌نشیند، جاده‌ی پیش‌رو دیده می‌شود
        var fwd := Vector2.RIGHT.rotated(heading)
        var spd_f := clampf(vel.length() / max_s, 0.0, 1.35)
        var lead := 165.0 + 215.0 * spd_f
        if racing_over:
                lead = 60.0
        var look := car_pos + fwd * lead + vel * 0.14
        cam.position = cam.position.lerp(look, delta * 5.0)
        if cam.position.distance_to(look) > 520.0:
                cam.position = look
        var zt := 1.07 - clampf(spd_f, 0.0, 1.0) * 0.22
        if nitro_on:
                zt -= 0.05
        cam.zoom = cam.zoom.lerp(Vector2(zt, zt), delta * 2.5)

func _update_brain_anchor() -> void:
        if car_anchor != null:
                var sp: Vector2 = car.get_global_transform_with_canvas().origin
                car_anchor.position = sp + Vector2(0.0, -120.0)

# ─────────────────────────── پایان و جشن ───────────────────────────
func _celebrate(win: bool) -> void:
        AudioMgr.set_skid(false)
        for i in 3:
                var c := CPUParticles2D.new()
                c.position = car_pos + Vector2(-200 + i * 200.0, -100.0)
                c.emitting = false
                c.amount = 40
                c.lifetime = 3.0
                c.direction = Vector2(0, 1)
                c.spread = 50.0
                c.gravity = Vector2(0, 260)
                c.initial_velocity_min = 60.0
                c.initial_velocity_max = 160.0
                c.scale_amount_min = 5.0
                c.scale_amount_max = 9.0
                var g := Gradient.new()
                g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
                var cols: Array = [Color(1.0, 0.42, 0.16), Color(1.0, 0.85, 0.2), Color(0.25, 0.75, 0.95)]
                g.colors = PackedColorArray([cols[i], cols[(i + 1) % 3], cols[(i + 2) % 3]])
                c.color_ramp = g
                c.z_index = 8
                world.add_child(c)
                c.emitting = win
        if brain != null and car_anchor != null:
                var my_id := str(Globals.CARS[Globals.selected_car]["id"])
                brain.say(car_anchor, my_id, "win" if win else "lose")

func _show_end(win: bool, stars: int, reward: int) -> void:
        end_panel = PanelContainer.new()
        end_panel.add_theme_stylebox_override("panel", _sb(Color(0.11, 0.12, 0.17), Color(0.85, 0.68, 0.28, 0.6), 24, 3))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 12)
        end_panel.add_child(vb)
        end_title = Label.new()
        end_title.text = ("قهرمان خیابان!" if finish_rank == 1 else Globals.L("win")) if win else Globals.L("lose")
        end_title.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
        end_title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.3))
        end_title.add_theme_font_size_override("font_size", 40)
        end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(end_title)
        end_stars = Label.new()
        end_stars.text = "٭٭٭".substr(0, stars) + "···".substr(0, 3 - stars) if stars > 0 else "---"
        end_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        end_stars.add_theme_font_size_override("font_size", 44)
        end_stars.add_theme_color_override("font_color", Color(0.72, 0.52, 0.1))
        vb.add_child(end_stars)
        end_reward = Label.new()
        end_reward.text = Globals.L("reward") + ": " + fa(reward) + " سکه  •  " + Globals.L("pos") + " " + fa(finish_rank) + "/" + fa(rivals.size() + 1)
        end_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        end_reward.add_theme_font_size_override("font_size", 26)
        end_reward.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
        vb.add_child(end_reward)
        var hb := HBoxContainer.new()
        hb.alignment = BoxContainer.ALIGNMENT_CENTER
        hb.add_theme_constant_override("separation", 14)
        end_retry_btn = Button.new()
        end_retry_btn.text = Globals.L("retry")
        end_retry_btn.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
        end_retry_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))
        _style_btn(end_retry_btn, true)
        hb.add_child(end_retry_btn)
        if win and int(lv["id"]) < 50:
                var b_next := Button.new()
                b_next.text = Globals.L("next")
                b_next.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
                b_next.pressed.connect(func():
                        Globals.set_meta("start_level", int(lv["id"]) + 1)
                        get_tree().change_scene_to_file("res://scenes/game.tscn"))
                _style_btn(b_next, true)
                hb.add_child(b_next)
        var b_menu := Button.new()
        b_menu.text = Globals.L("menu")
        b_menu.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
        b_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
        _style_btn(b_menu, false)
        hb.add_child(b_menu)
        end_menu_btn = b_menu
        vb.add_child(hb)
        hud.add_child(end_panel)
        _place(end_panel, 0.5, 0.5, 0.5, 0.5, -270, -175, 270, 135)
        end_panel.custom_minimum_size = Vector2(540, 310)
        end_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
        end_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

func _exit_tree() -> void:
        AudioMgr.set_engine(false)
        AudioMgr.set_skid(false)

# ─────────────────────────── تست خودکار ───────────────────────────
func _run_autotest(delta: float) -> void:
        _auto_timer += delta
        match _at_stage:
                0:
                        if _auto_timer > 0.6:
                                _at_stage = 1
                                _at_heading0 = heading
                                _press_at(Vector2(VIEW_W * 0.85, VIEW_H * 0.72)) # زون فرمان راست — نگه‌داشته
                1:
                        if _auto_timer > 0.75:
                                _at_stage = 2
                                _release_at(Vector2(VIEW_W * 0.85, VIEW_H * 0.72))
                                _press_at(Vector2(VIEW_W * 0.15, VIEW_H * 0.72)) # خنثی‌سازی — برگرد مسیر
                                var turned := absf(angle_difference(_at_heading0, heading))
                                print("[boghi][autotest] STEER-RIGHT ", "OK" if turned > 0.08 else "FAIL turned=" + str(turned))
                                if turned <= 0.08:
                                        get_tree().quit(1)
                2:
                        if _auto_timer > 0.9:
                                _at_stage = 3
                                _release_at(Vector2(VIEW_W * 0.15, VIEW_H * 0.72))
                                _press_at(Vector2(VIEW_W - 380.0, VIEW_H - 120.0)) # دکمه نیترو
                3:
                        if _auto_timer > 1.9:
                                _at_stage = 4
                                _release_at(Vector2(VIEW_W - 380.0, VIEW_H - 120.0))
                                print("[boghi][autotest] NITRO ", "OK" if nitro_meter < 0.98 else "FAIL")
                                if nitro_meter >= 0.98:
                                        get_tree().quit(1)
                4:
                        # تست دریفت: ترمز + فرمان راست در سرعت → لغزش + جیغ لاستیک
                        if _auto_timer > 2.4 and _at_stage == 4:
                                _at_stage = 7
                                _press_at(Vector2(380.0, VIEW_H - 120.0)) # ترمز
                                _press_at(Vector2(VIEW_W * 0.85, VIEW_H * 0.72)) # فرمان راست
                                _drift_seen = false
                7:
                        if drifting:
                                _drift_seen = true
                        if _auto_timer > 3.4:
                                _at_stage = 8
                                _release_at(Vector2(380.0, VIEW_H - 120.0))
                                _release_at(Vector2(VIEW_W * 0.85, VIEW_H * 0.72))
                                print("[boghi][autotest] DRIFT ", "OK" if _drift_seen else "FAIL")
                8:
                        if _auto_timer > 6.0:
                                var nr: Dictionary = _nearest(car_pos)
                                var img := get_viewport().get_texture().get_image()
                                if img != null:
                                        img.save_png("/home/z/my-project/scripts/shot_game.png")
                                print("AUTOTEST OK lap=", lap, " pos=", car_pos.round(), " spd=", int(vel.length()), " off=", nr["dist"] < ROAD_W * 0.5, " rank=", _calc_rank(), " rivals=", rivals.size(), " traf=", traffic.size(), " bld=", buildings.size(), " lamps=", lamps.size(), " nearest=", int(nr["dist"]))
                                get_tree().quit()

func _press_at(pos: Vector2) -> void:
        var ev := InputEventMouseButton.new()
        ev.button_index = MOUSE_BUTTON_LEFT
        ev.pressed = true
        ev.button_mask = MOUSE_BUTTON_MASK_LEFT
        ev.position = pos
        ev.global_position = pos
        Input.parse_input_event(ev)

func _release_at(pos: Vector2) -> void:
        var ev := InputEventMouseButton.new()
        ev.button_index = MOUSE_BUTTON_LEFT
        ev.pressed = false
        ev.position = pos
        ev.global_position = pos
        Input.parse_input_event(ev)

func _tap(btn: Button) -> void:
        _press_at(btn.get_global_rect().get_center())
        _release_at(btn.get_global_rect().get_center())

func _tap_at(pos: Vector2) -> void:
        _press_at(pos)
        _release_at(pos)

## تست چرخه کامل: توقف → ادامه → خط پایان سریع → پنل → دوباره → منو
func _autotest_full() -> void:
        await get_tree().create_timer(2.8).timeout # بعد از ۳-۲-۱-برو
        _tap(pause_btn)
        await get_tree().create_timer(0.3).timeout
        var p1: bool = get_tree().paused
        _tap(pause_btn)
        await get_tree().create_timer(0.3).timeout
        var p2: bool = get_tree().paused
        print("[boghi][autotest] TAP-PAUSE ", "OK" if (p1 and not p2) else "FAIL")
        if not (p1 and not p2):
                get_tree().quit(1)
                return
        # پرش به انتهای دور آخر
        lap = LAPS - 1
        path_s = track_len * 0.96
        car_pos = _path_pos(path_s)
        heading = _path_dir(path_s).angle()
        vel = _path_dir(path_s) * max_s
        await get_tree().create_timer(1.6).timeout
        var nd1: Dictionary = _nearest(car_pos)
        print("[boghi][autotest] diag1 pos=", car_pos.round(), " s=", int(path_s), " lap=", lap, " vel=", int(vel.length()), " dist=", int(nd1["dist"]), " over=", racing_over)
        for b in buildings:
                var loc: Vector2 = (car_pos - b["pos"]).rotated(-float(b["rot"]))
                var hx: float = b["size"].x * 0.5 + 20.0
                var hy: float = b["size"].y * 0.5 + 20.0
                if absf(loc.x) < hx + 40.0 and absf(loc.y) < hy + 40.0:
                        print("[diag] bld: pos=", b["pos"].round(), " sz=", b["size"].round(), " loc=", loc.round())
        for so2 in solids:
                if car_pos.distance_to(so2["pos"]) < 140.0:
                        print("[diag] solid: ", so2["pos"].round(), " r=", so2["r"], " d=", int(car_pos.distance_to(so2["pos"])))
        await get_tree().create_timer(3.8).timeout
        var nd2: Dictionary = _nearest(car_pos)
        print("[boghi][autotest] diag2 pos=", car_pos.round(), " s=", int(path_s), " lap=", lap, " vel=", int(vel.length()), " dist=", int(nd2["dist"]), " over=", racing_over)
        if end_panel == null or end_retry_btn == null or end_menu_btn == null:
                print("[boghi][autotest] END-PANEL FAIL")
                get_tree().quit(1)
                return
        print("[boghi][autotest] END-PANEL OK")
        var img := get_viewport().get_texture().get_image()
        if img != null:
                img.save_png("/home/z/my-project/scripts/shot_end_panel.png")
        if not Globals.has_meta("at_retry"):
                Globals.set_meta("at_retry", 1)
                _tap(end_retry_btn)
                return # صحنه دوباره لود می‌شود؛ نسخه جدید ادامه می‌دهد
        Globals.set_meta("at_menu_return", true)
        _tap(end_menu_btn)
        await get_tree().create_timer(3.0).timeout
        print("[boghi][autotest] TAP-ENDMENU FAIL (منو لود نشد)")
        get_tree().quit(1)

# ─────────────────────────── شات‌های بصری (--shots) ───────────────────────────
func _save_shot(fname: String) -> void:
        var img := get_viewport().get_texture().get_image()
        if img != null:
                img.save_png("/home/z/my-project/scripts/" + fname)
                print("[boghi][shots] saved ", fname)

## خط زمانی شات: شمارش معکوس → نیترو → دریفت → خیابان با ترافیک و رقیب
func _run_shots() -> void:
        await get_tree().create_timer(0.25).timeout
        print("[shots] cd: text=", intro_label.text, " vis=", intro_label.visible, " a=", intro_label.modulate.a, " stage=", _intro_stage, " intro=", intro)
        _save_shot("shot_race_countdown.png")
        await get_tree().create_timer(2.6).timeout # بعد از «برو!»
        nitro_meter = 1.0
        nitro_held = true
        await get_tree().create_timer(1.35).timeout
        _save_shot("shot_race_nitro.png")
        nitro_held = false
        _press_at(Vector2(380.0, VIEW_H - 120.0)) # ترمز + فرمان راست = دریفت واقعی
        _press_at(Vector2(VIEW_W * 0.85, VIEW_H * 0.72))
        await get_tree().create_timer(0.85).timeout
        _save_shot("shot_race_drift.png")
        _release_at(Vector2(380.0, VIEW_H - 120.0))
        _release_at(Vector2(VIEW_W * 0.85, VIEW_H * 0.72))
        # برگشت بازیکن به مسیر — شات خیابان باید تمیز باشد
        await get_tree().create_timer(0.3).timeout
        path_s += 640.0
        car_pos = _path_pos(path_s)
        heading = _path_dir(path_s).angle()
        vel = _path_dir(path_s) * max_s * 0.9
        var my := float(lap) * track_len + path_s
        _spawn_traffic(my + 700.0)
        _spawn_traffic(my + 940.0)
        _spawn_coins(my + 520.0)
        await get_tree().create_timer(1.5).timeout
        _save_shot("shot_race_street.png")
        print("[boghi][shots] OK")
        get_tree().quit()

# ─────────────────────────── ابزار ───────────────────────────
func fa(n: int) -> String:
        var s := str(n)
        var out := ""
        for ch in s:
                if ch >= "0" and ch <= "9":
                        out += FA_D[int(ch)]
                else:
                        out += ch
        return out