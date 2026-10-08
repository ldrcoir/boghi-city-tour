#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پچ منوی v0.16 — حذف ماسکوت بچه‌ها، ماشین زنده‌ی درایو-بای، فیکس تداخل تیتر/پنل،
کلیک و هاور روی همه‌ی دکمه‌ها."""
import io

P = "/home/z/my-project/game/scripts/menu.gd"
src = io.open(P, encoding="utf-8").read()
n0 = len(src)

# ─── ۱) متغیرهای درایو ───
old = """var deco_cars: Array = []"""
new = """var deco_cars: Array = []
var _drive_car: Node2D = null
var _drive_spd := 220.0"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۲) جایگزینی کامل _deco_cars — ماسکوت بچه‌ها ممنوع؛ بوقی واقعی رد می‌شود ───
start = src.find("## ماشین قهرمان — اسپرایت top-down هنر نو با آندرگلو بیک‌شده")
end = src.find("## تیتر موتوری")
assert start != -1 and end != -1 and end > start
NEW_DECO = '''## ماشین زنده‌ی منو — بوقی top-down با مخروط نور، در خیابان پایینِ نقاشی رد می‌شود
func _deco_cars() -> void:
        var tex := _safe_load("res://assets/sprites/boghi_top.png")
        if tex == null:
                return
        _drive_car = Node2D.new()
        var lmat := CanvasItemMaterial.new()
        lmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        var sh := Sprite2D.new()
        sh.texture = _safe_load("res://assets/sprites/light_soft.png")
        sh.scale = Vector2(2.6, 1.2)
        sh.modulate = Color(0, 0, 0.02, 0.5)
        sh.position = Vector2(4, 14)
        _drive_car.add_child(sh)
        var ug := Sprite2D.new()
        ug.texture = _safe_load("res://assets/sprites/light_soft.png")
        ug.scale = Vector2(2.4, 0.95)
        ug.modulate = Color(0.5, 0.9, 1.0, 0.32)
        ug.material = lmat
        ug.position = Vector2(0, 8)
        _drive_car.add_child(ug)
        var cone := Sprite2D.new()
        cone.texture = _safe_load("res://assets/sprites/headlight_cone.png")
        cone.centered = false
        cone.position = Vector2(26, -104)
        cone.scale = Vector2(0.8, 0.8)
        cone.material = lmat
        cone.modulate = Color(1.0, 0.95, 0.8, 0.42)
        _drive_car.add_child(cone)
        var spr := Sprite2D.new()
        spr.texture = tex
        spr.scale = Vector2(1.3, 1.3)
        _drive_car.add_child(spr)
        add_child(_drive_car)
        move_child(_drive_car, 1)  # پشت پنل/تیتر — جلوی پس‌زمینه
        _drive_reset(true)
        set_process(true)

var _drive_wait := 0.0

func _drive_reset(first: bool) -> void:
        var from_left := randf() < 0.5
        _drive_car.position = Vector2(-280.0 if from_left else 1560.0, randf_range(648.0, 678.0))
        _drive_spd = (1.0 if from_left else -1.0) * randf_range(190.0, 280.0)
        _drive_car.scale = Vector2.ONE
        _drive_car.skew = 0.0
        if not from_left:
                # رد شدن از راست به چپ — ماشین برعکس (rotation π) و کمی پایین‌تر
                _drive_car.rotation = PI
                _drive_car.position.y += 6.0
        else:
                _drive_car.rotation = 0.0
        _drive_wait = randf_range(2.2, 5.0) if not first else 0.8

func _process(delta: float) -> void:
        if _drive_car == null:
                return
        if _drive_wait > 0.0:
                _drive_wait -= delta
                return
        _drive_car.position.x += _drive_spd * delta
        # لرزش خیلی ظریف جاده — حس موتور روشن
        _drive_car.position.y += sin(Time.get_ticks_msec() * 0.02) * 0.06
        if _drive_car.position.x < -340.0 or _drive_car.position.x > 1620.0:
                _drive_reset(false)

'''
src = src[:start] + NEW_DECO + src[end:]

# ─── ۳) فیکس تداخل تیتر/پنل ───
old = """        panel_home.custom_minimum_size = Vector2(560, 488)
        panel_home.set_anchors_preset(Control.PRESET_CENTER)
        panel_home.offset_top = 176.0 # کاملاً زیر زیرنویس نو (تا y≈۱۷۰) — تداخل ممنوع"""
new = """        panel_home.custom_minimum_size = Vector2(560, 466)
        panel_home.set_anchors_preset(Control.PRESET_CENTER)
        panel_home.offset_top = 228.0 # زیرنویس تا y=۲۱۶ — هشت پیکسل نفس"""
assert old in src; src = src.replace(old, new, 1)

# ─── ۴) کلیک + هاور حرفه‌ای روی دکمه‌ها ───
old = """        b.custom_minimum_size = Vector2(320, h)
        _style_btn(b, kind)
        return b"""
new = """        b.custom_minimum_size = Vector2(320, h)
        _style_btn(b, kind)
        # فیدبک شنیداری/بصری — منوی زنده
        b.pressed.connect(func():
                if has_node("/root/AudioMgr"):
                        get_node("/root/AudioMgr").ui_click())
        b.mouse_entered.connect(func(): b.modulate = Color(1.12, 1.12, 1.1))
        b.mouse_exited.connect(func(): b.modulate = Color.WHITE)
        return b"""
assert old in src; src = src.replace(old, new, 1)

io.open(P, "w", encoding="utf-8").write(src)
print("menu.gd patched:", n0, "->", len(src))
