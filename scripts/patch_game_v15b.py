#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""patch_game_v15b — فیکس‌های راند ۲ + اتوپایلوت playtest (خودم بازی می‌کنم)"""
import sys

P = "/home/z/my-project/game/scripts/game.gd"
src = open(P, encoding="utf-8").read()

def rep(old, new, cnt=1):
    global src
    c = src.count(old)
    if c != cnt:
        print("FAIL (%d):" % c, old[:80].replace("\n", "\\n"))
        sys.exit(1)
    src = src.replace(old, new)

# A) زیرلایه‌ی تاریک زیر نقشه — هیچ‌وقت خاکستریِ بیرون دیده نشود
rep("""        # نقشه‌ی شهر — ۴ تایل بیک‌شده (gen15_map) — کیفیت ۱:۱
        var tw := map_rect.size.x * 0.5""",
"""        # زیرلایه‌ی تاریک کل دنیا — بیرونِ نقشه هم شب است، نه خاکستری
        var under := ColorRect.new()
        under.color = Color(0.027, 0.031, 0.055)
        under.position = map_rect.position - Vector2(4000, 4000)
        under.size = map_rect.size + Vector2(8000, 8000)
        world.add_child(under)
        # نقشه‌ی شهر — ۴ تایل بیک‌شده (gen15_map) — کیفیت ۱:۱
        var tw := map_rect.size.x * 0.5""")

# B) دوربین داخل محدوده نقشه بماند
rep("""        var zt := 1.07 - clampf(spd_f, 0.0, 1.0) * 0.22
        if nitro_on:
                zt -= 0.05
        cam.zoom = cam.zoom.lerp(Vector2(zt, zt), delta * 2.5)""",
"""        var zt := 1.07 - clampf(spd_f, 0.0, 1.0) * 0.22
        if nitro_on:
                zt -= 0.05
        cam.zoom = cam.zoom.lerp(Vector2(zt, zt), delta * 2.5)
        # دوربین هرگز از لبه‌ی نقشه بیرون نمی‌رود
        var half := Vector2(VIEW_W, VIEW_H) * 0.5 / cam.zoom
        var lo := map_rect.position + half * 0.55
        var hi := map_rect.end - half * 0.55
        cam.position = Vector2(clampf(cam.position.x, lo.x, hi.x), clampf(cam.position.y, lo.y, hi.y))""")

# D) دکمه‌های شیشه‌ای — نه مکعب تخت
rep("""        var nfs := _sb(Color(0.13, 0.35, 0.75), Color(0.35, 0.6, 1.0), 18, 3)
        btn_nitro.add_theme_stylebox_override("normal", nfs)
        btn_nitro.add_theme_stylebox_override("hover", _sb(Color(0.18, 0.42, 0.85), Color(0.45, 0.7, 1.0), 18, 3))
        btn_nitro.add_theme_stylebox_override("pressed", _sb(Color(0.1, 0.25, 0.55), Color(0.35, 0.6, 1.0), 18, 3))
        btn_nitro.add_theme_stylebox_override("disabled", nfs)
        btn_nitro.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))""",
"""        var nfs := _sb(Color(0.09, 0.20, 0.38, 0.78), Color(0.45, 0.72, 1.0, 0.75), 22, 2)
        btn_nitro.add_theme_stylebox_override("normal", nfs)
        btn_nitro.add_theme_stylebox_override("hover", _sb(Color(0.13, 0.27, 0.48, 0.85), Color(0.6, 0.82, 1.0, 0.9), 22, 2))
        btn_nitro.add_theme_stylebox_override("pressed", _sb(Color(0.06, 0.14, 0.28, 0.9), Color(0.45, 0.72, 1.0, 0.9), 22, 2))
        btn_nitro.add_theme_stylebox_override("disabled", nfs)
        btn_nitro.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))""")
rep("""        btn_brake.add_theme_stylebox_override("normal", _sb(Color(0.45, 0.13, 0.13), Color(0.75, 0.3, 0.25), 18, 3))
        btn_brake.add_theme_stylebox_override("hover", _sb(Color(0.55, 0.18, 0.16), Color(0.8, 0.35, 0.3), 18, 3))
        btn_brake.add_theme_stylebox_override("pressed", _sb(Color(0.32, 0.08, 0.08), Color(0.75, 0.3, 0.25), 18, 3))
        btn_brake.add_theme_stylebox_override("disabled", _sb(Color(0.45, 0.13, 0.13), Color(0.75, 0.3, 0.25), 18, 3))
        btn_brake.add_theme_color_override("font_color", Color(1.0, 0.9, 0.85))""",
"""        btn_brake.add_theme_stylebox_override("normal", _sb(Color(0.34, 0.10, 0.10, 0.78), Color(0.9, 0.42, 0.35, 0.65), 22, 2))
        btn_brake.add_theme_stylebox_override("hover", _sb(Color(0.42, 0.14, 0.13, 0.85), Color(1.0, 0.5, 0.42, 0.8), 22, 2))
        btn_brake.add_theme_stylebox_override("pressed", _sb(Color(0.24, 0.07, 0.07, 0.9), Color(0.9, 0.42, 0.35, 0.9), 22, 2))
        btn_brake.add_theme_stylebox_override("disabled", _sb(Color(0.34, 0.10, 0.10, 0.78), Color(0.9, 0.42, 0.35, 0.65), 22, 2))
        btn_brake.add_theme_color_override("font_color", Color(1.0, 0.92, 0.88))""")

# E) عدد شمارش زیر نوار پیشرفت
rep("""        intro_label.anchor_top = 0.26
        intro_label.anchor_bottom = 0.26""",
"""        intro_label.anchor_top = 0.335
        intro_label.anchor_bottom = 0.335""")

# F) مینی‌مپ بالای راست — زیر برچسب زمان، دور از فلش‌های فرمان
rep("""        _place(minimap, 1.0, 1.0, 1.0, 1.0, -268, -238, -20, -20)""",
"""        _place(minimap, 1.0, 0.0, 1.0, 0.0, -252, 158, -28, 350)""")

# G) playtest — اتوپایلوت واقعی؛ من راننده‌ام
rep("""# ─────────────────────────── شات‌های بصری (--shots) ───────────────────────────""",
"""## پلی‌تست کامل — اتوپایلوت مسیر را دور می‌زند؛ شات در همه‌ی مراحل
func _run_playtest() -> void:
        var dir_exec := get_viewport()
        await get_tree().create_timer(0.4).timeout
        _save_shot("pt_1_countdown.png")
        await get_tree().create_timer(2.7).timeout
        print("[playtest] GO — رانندگی شروع")
        var t0 := Time.get_ticks_msec()
        var top_spd := 0.0
        var shots_done := {}
        var plan := {6.0: "pt_2_start.png", 14.0: "pt_3_straight.png", 22.0: "pt_4_corner.png",
                34.0: "pt_5_midrace.png", 46.0: "pt_6_traffic.png", 58.0: "pt_7_final.png"}
        while not racing_over and ended == false:
                await get_tree().process_frame
                var el := (Time.get_ticks_msec() - t0) / 1000.0
                # — راننده: نگاه به نقطه‌ی پیش‌رو
                var ahead := 300.0 + vel.length() * 0.45
                var tgt := _path_pos(path_s + ahead)
                var d := _path_dir(path_s + ahead)
                var nn := Vector2(-d.y, d.x)
                tgt += nn * 30.0
                var want := (tgt - car_pos).angle()
                var diff := angle_difference(heading, want)
                kb_left = diff < -0.03
                kb_right = diff > 0.03
                var d2 := _path_dir(path_s + 700.0)
                var curve := absf(d.angle_to(d2))
                nitro_held = curve < 0.06 and nitro_meter > 0.5
                brake_held = curve > 0.5 and vel.length() > max_s * 0.75
                top_spd = maxf(top_spd, vel.length())
                for k in plan:
                        if el > float(k) and not shots_done.has(k):
                                shots_done[k] = true
                                _save_shot(plan[k])
                                print("[playtest] shot ", plan[k], " t=", int(el), " spd=", int(vel.length()), " lap=", lap + 1, " rank=", _calc_rank())
                if el > 220.0:
                        break
        var total := (Time.get_ticks_msec() - t0) / 1000.0
        print("[playtest] FINISH rank=", finish_rank, " time=", int(total), "s top=", int(top_spd * 0.21), "kmh coins=", coins_got)
        await get_tree().create_timer(2.9).timeout
        _save_shot("pt_8_result.png")
        print("[playtest] DONE")
        get_tree().quit()

# ─────────────────────────── شات‌های بصری (--shots) ───────────────────────────""")

# اتصال playtest در _ready
rep("""        if autotest_full:
                _autotest_full()
        if shots:
                _run_shots()""",
"""        if autotest_full:
                _autotest_full()
        if shots:
                _run_shots()
        if OS.get_cmdline_user_args().has("--playtest"):
                time_left = 9999.0
                _run_playtest()""")

open(P, "w", encoding="utf-8").write(src)
print("game.gd v15b patched")
