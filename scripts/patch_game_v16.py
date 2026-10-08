#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پچ game.gd برای v0.16 — وسواس واقعی‌بودن:
گیربکس مجازی ۵ دنده + دور موتور اره‌ای، صدای تعویض دنده، باد سرعت،
پانچ نیترو، جرقه برخورد، دود دنده‌عقبِ درجا، چراغ ترمز بازیکن و رقیب."""
import io

P = "/home/z/my-project/game/scripts/game.gd"
src = io.open(P, encoding="utf-8").read()
n0 = len(src)

# ─── ۱) ثابت گیربکس + متغیرها ───
old = """const NITRO_MULT := 1.40"""
new = """const NITRO_MULT := 1.40
# گیربکس مجازی — مرزهای دنده بر حسب کسر سرعت ماکزیمم (حس واقعی دور موتور)
const GEARS := [0.0, 0.15, 0.31, 0.50, 0.72, 1.02]"""
assert old in src; src = src.replace(old, new, 1)

old = """var nitro_on := false
var nitro_meter := 1.0
var nitro_drain := 0.30"""
new = """var nitro_on := false
var nitro_meter := 1.0
var nitro_drain := 0.30
var _nitro_was := false
var gear := 1
var rpm_s := 0.16
var _shift_cd := 0.0
var brake_glow: Sprite2D = null
var puff: CPUParticles2D = null"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۲) چراغ ترمز + دود درجا در _make_car_node ───
old = """        var fl: CPUParticles2D = null
        var sm: CPUParticles2D = null
        if with_fx:"""
new = """        var fl: CPUParticles2D = null
        var sm: CPUParticles2D = null
        var pf: CPUParticles2D = null
        var brk := Sprite2D.new()
        brk.texture = load("res://assets/sprites/light_soft.png")
        brk.position = Vector2(-93, 0)
        brk.scale = Vector2(0.55, 0.40)
        brk.modulate = Color(1.0, 0.16, 0.10, 0.10)
        var bmat := CanvasItemMaterial.new()
        bmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        brk.material = bmat
        brk.z_index = 1
        n.add_child(brk)
        if with_fx:"""
assert old in src; src = src.replace(old, new, 1)

old = """                sm = sm2
                n.add_child(sm2)
        return {"node": n, "spr": spr, "flame": fl, "smoke": sm}"""
new = """                sm = sm2
                n.add_child(sm2)
                # دود آرام اگزوز درجا — نفس موتور خام
                pf = CPUParticles2D.new()
                pf.position = Vector2(-97, 8)
                pf.emitting = false
                pf.amount = 7
                pf.lifetime = 1.15
                pf.direction = Vector2(-1, 0)
                pf.spread = 15.0
                pf.initial_velocity_min = 24.0
                pf.initial_velocity_max = 58.0
                pf.scale_amount_min = 2.2
                pf.scale_amount_max = 4.2
                pf.texture = load("res://assets/sprites/smoke.png")
                var pg := Gradient.new()
                pg.offsets = PackedFloat32Array([0.0, 1.0])
                pg.colors = PackedColorArray([Color(0.76, 0.76, 0.8, 0.3), Color(0.7, 0.7, 0.76, 0.0)])
                pf.color_ramp = pg
                n.add_child(pf)
        return {"node": n, "spr": spr, "flame": fl, "smoke": sm, "puff": pf, "brake": brk}"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۳) _build_car: گرفتن پاف/بریک ───
old = """        car_sprite = fx["spr"]
        flame = fx["flame"]
        smoke = fx["smoke"]"""
new = """        car_sprite = fx["spr"]
        flame = fx["flame"]
        smoke = fx["smoke"]
        puff = fx["puff"]
        brake_glow = fx["brake"]"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۴) رقیب‌ها: ذخیره چراغ ترمز ───
old = """                rivals.append({
                        "node": fx["node"], "spr": fx["spr"],
                        "s": float(starts[i]), "spd": 0.0,
                        "pace": randf_range(0.965, 1.045),
                        "lane": float(lanes[i]), "lane_cur": float(lanes[i]),
                        "ang": 0.0, "corner": false, "mt": 0.0,
                })"""
new = """                rivals.append({
                        "node": fx["node"], "spr": fx["spr"],
                        "s": float(starts[i]), "spd": 0.0,
                        "pace": randf_range(0.965, 1.045),
                        "lane": float(lanes[i]), "lane_cur": float(lanes[i]),
                        "ang": 0.0, "corner": false, "mt": 0.0,
                        "brake": fx["brake"], "dec": false,
                })"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۵) پانچ نیترو — ضربه‌ی لحظه‌ای گاز ───
old = """        # نیترو
        nitro_on = nitro_held and nitro_meter > 0.02 and not brake_held
        if nitro_on:"""
new = """        # نیترو — با پانچ لحظه‌ای (حس تزریق)
        nitro_on = nitro_held and nitro_meter > 0.02 and not brake_held
        if nitro_on and not _nitro_was:
                vel += fwd * 135.0
                shake = maxf(shake, 1.4)
        _nitro_was = nitro_on
        if nitro_on:"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۶) موتور توقف/پایان → stop_driving_loops ───
old = """        if racing_over:
                # بعد خط پایان — ماشین آروم می‌ایستد، دنیا زنده می‌ماند
                vel *= exp(-1.6 * delta)
                car_pos += vel * delta
                car.position = car_pos
                AudioMgr.set_engine(false)
                AudioMgr.set_skid(false)
                return"""
new = """        if racing_over:
                # بعد خط پایان — ماشین آروم می‌ایستد، دنیا زنده می‌ماند
                vel *= exp(-1.6 * delta)
                car_pos += vel * delta
                car.position = car_pos
                AudioMgr.stop_driving_loops()
                return"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۷) گیربکس/دور موتور/باد — قلب صدای واقعی ───
old = """        # صدا + افکت
        AudioMgr.set_engine(true, clampf(absf(vf) / max_s, 0.12, 1.0) * (1.12 if nitro_on else 1.0))
        if flame != null:
                flame.emitting = nitro_on
        if lines != null:
                lines.visible = nitro_on"""
new = """        # گیربکس مجازی — دور موتور اره‌ای: بالا می‌رود، دنده عوض می‌شود، می‌افتد
        var sn2 := clampf(absf(vf) / max_s, 0.0, 1.04)
        var g := 1
        while g < GEARS.size() and sn2 > GEARS[g]:
                g += 1
        var lo := float(GEARS[g - 1])
        var hi := float(GEARS[g])
        var rt := clampf((sn2 - lo) / maxf(0.02, hi - lo), 0.0, 1.0)
        rt = 0.16 + 0.84 * rt
        if nitro_on:
                rt = minf(1.0, rt + 0.12)
        rpm_s = lerpf(rpm_s, rt, minf(1.0, delta * 11.0))
        if g != gear:
                if g > gear and sn2 > 0.06 and _shift_cd <= 0.0:
                        AudioMgr.play_sfx("shift", -11.0)
                        _shift_cd = 0.22
                gear = g
        _shift_cd = maxf(0.0, _shift_cd - delta)
        AudioMgr.set_engine_ex(true, rpm_s, 0.25 if brake_held else 1.0, nitro_on)
        AudioMgr.set_wind(clampf(sn2 * 1.08, 0.0, 1.0))
        if flame != null:
                flame.emitting = nitro_on
        if lines != null:
                lines.visible = nitro_on
        if puff != null:
                puff.emitting = absf(vf) < 95.0
        if brake_glow != null:
                var btgt := 0.85 if (brake_held or (drifting and absf(vf) > 190.0)) else 0.1
                brake_glow.modulate.a = lerpf(brake_glow.modulate.a, btgt, minf(1.0, delta * 10.0))"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۸) جرقه برخورد ───
old = """func _resolve_buildings() -> void:"""
new = """func _spawn_sparks(p: Vector2, n: int = 15) -> void:
        var sp := CPUParticles2D.new()
        sp.position = p
        sp.amount = n
        sp.lifetime = 0.5
        sp.one_shot = true
        sp.explosiveness = 1.0
        sp.direction = Vector2.UP
        sp.spread = 180.0
        sp.gravity = Vector2(0, 950)
        sp.initial_velocity_min = 170.0
        sp.initial_velocity_max = 430.0
        sp.scale_amount_min = 1.6
        sp.scale_amount_max = 3.4
        var sg := Gradient.new()
        sg.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
        sg.colors = PackedColorArray([Color(1.0, 0.92, 0.6), Color(1.0, 0.55, 0.2), Color(0.8, 0.2, 0.05, 0.0)])
        sp.color_ramp = sg
        world.add_child(sp)
        sp.emitting = true
        get_tree().create_timer(1.3).timeout.connect(sp.queue_free)

func _resolve_buildings() -> void:"""
assert old in src; src = src.replace(old, new, 1)

old = """                        if elapsed > bump_cd:
                                bump_cd = elapsed + 0.5
                                vel *= 0.42
                                shake = 7.0
                                AudioMgr.play_sfx("crash")"""
new = """                        if elapsed > bump_cd:
                                bump_cd = elapsed + 0.5
                                vel *= 0.42
                                shake = 7.0
                                AudioMgr.play_sfx("crash")
                                _spawn_sparks(car_pos - vel.normalized() * 34.0 if vel.length() > 20.0 else car_pos, 16)"""
assert old in src; src = src.replace(old, new, 1)

old = """                        if elapsed > bump_cd:
                                bump_cd = elapsed + 0.5
                                vel *= 0.55
                                shake = maxf(shake, 4.0)
                                AudioMgr.play_sfx("clank")"""
new = """                        if elapsed > bump_cd:
                                bump_cd = elapsed + 0.5
                                vel *= 0.55
                                shake = maxf(shake, 4.0)
                                AudioMgr.play_sfx("clank")
                                _spawn_sparks(so["pos"] + dv.normalized() * float(so["r"]), 8)"""
assert old in src; src = src.replace(old, new, 1)

old = """                if car_pos.distance_to(tp) < 74.0 and elapsed > invuln_until:
                        invuln_until = elapsed + 1.1
                        vel *= 0.34
                        shake = 10.0
                        AudioMgr.play_sfx("crash")"""
new = """                if car_pos.distance_to(tp) < 74.0 and elapsed > invuln_until:
                        invuln_until = elapsed + 1.1
                        vel *= 0.34
                        shake = 10.0
                        AudioMgr.play_sfx("crash")
                        _spawn_sparks((car_pos + tp) * 0.5, 18)"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۹) چراغ ترمز رقیب ───
old = """                        R["corner"] = ang > 0.3
                        R["spd"] = lerpf(float(R["spd"]), base * cs, delta * 2.0)"""
new = """                        R["corner"] = ang > 0.3
                        R["dec"] = cs < 0.82
                        R["spd"] = lerpf(float(R["spd"]), base * cs, delta * 2.0)"""
assert old in src; src = src.replace(old, new, 1)

old = """                R["ang"] = absf(dd.angle_to(Vector2.RIGHT.rotated(float(R["node"].rotation))))"""
new = """                R["ang"] = absf(dd.angle_to(Vector2.RIGHT.rotated(float(R["node"].rotation))))
                # چراغ ترمز رقیب — موقع کند شدن در پیچ می‌سوزد
                var brk: Sprite2D = R["brake"]
                var btgt := 0.8 if (racing and bool(R["dec"])) else 0.08
                brk.modulate.a = lerpf(brk.modulate.a, btgt, minf(1.0, delta * 9.0))"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۱۰) موتور شمارش معکوس از مسیر ex ───
old = """                AudioMgr.set_engine(true, clampf(0.85 - intro * 0.3, 0.15, 0.85))"""
new = """                AudioMgr.set_engine_ex(true, clampf(0.85 - intro * 0.3, 0.15, 0.85), 0.55, false)"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۱۱) توقف پرده — stop_driving_loops ───
old = """        AudioMgr.set_engine(not t.paused, 0.3)
        AudioMgr.set_skid(false)"""
new = """        AudioMgr.set_engine(not t.paused, 0.3)
        AudioMgr.set_skid(not t.paused, 0.0)
        AudioMgr.set_wind(0.0 if t.paused else 0.2)"""
assert old in src; src = src.replace(old, new, 1)

io.open(P, "w", encoding="utf-8").write(src)
import py_compile
print("game.gd patched:", n0, "->", len(src))
