#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""patch_menu_v15 — بازطراحی منو: پس‌زمینه سینمایی نو + تیتر با درخشش +
ماشین قهرمان top-down (نه کارتون چشم‌دار) + گلس تیره."""
import sys

P = "/home/z/my-project/game/scripts/menu.gd"
src = open(P, encoding="utf-8").read()

def rep(old, new, cnt=1):
    global src
    c = src.count(old)
    if c != cnt:
        print("FAIL (%d):" % c, old[:80].replace("\n", "\\n"))
        sys.exit(1)
    src = src.replace(old, new)

# ۱) پس‌زمینه: png نو
rep('var tex := _safe_load("res://assets/sprites/menu_bg.webp")',
    'var tex := _safe_load("res://assets/sprites/menu_bg.png")\n\t\tif tex == null:\n\t\t\ttex = _safe_load("res://assets/sprites/menu_bg.webp")')

# ۲) پالت: شیشه‌ی تیره‌تر و جدی
rep("""const COL_GLASS := Color(0.10, 0.11, 0.13, 0.90)""",
    """const COL_GLASS := Color(0.055, 0.065, 0.10, 0.93)""")

# ۳) تیتر — بزرگ با درخشش + زیرنویس جدای «تور شهرها»
rep("""func _build_title() -> void:
        var title := _mk_label("بوقی: تور شهرها", 54, false, true, COL_GOLD)
        title.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.03))
        title.add_theme_constant_override("outline_size", 14)
        title.anchor_left = 0.0
        title.anchor_right = 1.0
        title.offset_top = SAFE_TOP
        title.offset_bottom = SAFE_TOP + 66
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(title)
        title_nodes.append(title)
        var bar := Panel.new()
        bar.add_theme_stylebox_override("panel", _sb(COL_RED, Color(0, 0, 0, 0), 3))
        bar.anchor_left = 0.5
        bar.anchor_right = 0.5
        bar.offset_left = -100.0
        bar.offset_right = 100.0
        bar.offset_top = SAFE_TOP + 72
        bar.offset_bottom = SAFE_TOP + 79
        add_child(bar)
        title_nodes.append(bar)
        var sub := _mk_label("فصل ۱ — تهران  •  ۵۰ مأموریت محله", 20, true, false, Color(1, 1, 1, 0.88))
        sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
        sub.add_theme_constant_override("outline_size", 6)
        sub.anchor_left = 0.0
        sub.anchor_right = 1.0
        sub.offset_top = SAFE_TOP + 84
        sub.offset_bottom = SAFE_TOP + 114
        sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(sub)
        title_nodes.append(sub)""",
"""func _build_title() -> void:
        # هاله‌ی طلایی پشت تیتر
        var glow := TextureRect.new()
        glow.texture = _safe_load("res://assets/sprites/title_glow.png")
        if glow.texture != null:
                glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                glow.stretch_mode = TextureRect.STRETCH_SCALE
                glow.anchor_left = 0.5
                glow.anchor_right = 0.5
                glow.offset_left = -320.0
                glow.offset_right = 320.0
                glow.offset_top = SAFE_TOP - 46.0
                glow.offset_bottom = SAFE_TOP + 118.0
                glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
                glow.modulate = Color(1.0, 0.9, 0.6, 0.85)
                add_child(glow)
                title_nodes.append(glow)
        var title := _mk_label("بوقی", 108, false, true, Color(1.0, 0.87, 0.42))
        title.add_theme_color_override("font_outline_color", Color(0.14, 0.05, 0.02))
        title.add_theme_constant_override("outline_size", 18)
        title.anchor_left = 0.0
        title.anchor_right = 1.0
        title.offset_top = SAFE_TOP - 8
        title.offset_bottom = SAFE_TOP + 118
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(title)
        title_nodes.append(title)
        # خط نئونی دوتایی زیر لوگو
        var bar := Panel.new()
        bar.add_theme_stylebox_override("panel", _sb(Color(1.0, 0.62, 0.16, 0.95), Color(0, 0, 0, 0), 2))
        bar.anchor_left = 0.5
        bar.anchor_right = 0.5
        bar.offset_left = -96.0
        bar.offset_right = 96.0
        bar.offset_top = SAFE_TOP + 122
        bar.offset_bottom = SAFE_TOP + 127
        add_child(bar)
        title_nodes.append(bar)
        var sub := _mk_label("تور شهرها  •  فصل ۱: تهران", 26, true, false, Color(0.94, 0.92, 0.88, 0.95))
        sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
        sub.add_theme_constant_override("outline_size", 7)
        sub.anchor_left = 0.0
        sub.anchor_right = 1.0
        sub.offset_top = SAFE_TOP + 134
        sub.offset_bottom = SAFE_TOP + 170
        sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(sub)
        title_nodes.append(sub)""")

# ۴) پنل خانه — کمی پایین‌تر چون تیتر بلندتر شد
rep("""        panel_home.offset_top = 130.0 # کاملاً زیر زیرنویس (زیرنویس تا y≈۱۱۴) — تداخل ممنوع""",
    """        panel_home.offset_top = 176.0 # کاملاً زیر زیرنویس نو (تا y≈۱۷۰) — تداخل ممنوع""")

# ۵) ماشین‌های دکوری قدیمی → ماشین قهرمان top-down
i0 = src.index("## ماشین‌های قهرمان محله — پایین-چپ")
i1 = src.index("## تیتر موتوری — همیشه رندر می‌شود")
src = src[:i0] + src[i1:]

# ۶) قهرمان نو — پایین-چپ، نفس‌کشنده، بدون حباب حرف
rep("""## تیتر موتوری — همیشه رندر می‌شود؛ داخل ناحیه امن استاتوس‌بار""",
"""## ماشین قهرمان — اسپرایت top-down هنر نو با آندرگلو بیک‌شده
func _deco_cars() -> void:
        var hero := TextureRect.new()
        var htex := _safe_load("res://assets/sprites/menu_hero.png")
        if htex == null:
                return
        hero.texture = htex
        hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        hero.anchor_left = 0.02
        hero.anchor_right = 0.02
        hero.anchor_top = 1.0
        hero.anchor_bottom = 1.0
        hero.offset_left = -20.0
        hero.offset_right = 250.0
        hero.offset_top = -400.0
        hero.offset_bottom = 30.0
        hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(hero)
        deco_cars.append(hero)
        move_child(hero, 1)
        if brain != null:
                BRAIN_SCRIPT.add_breathing(hero, 4.0, 1.1)

## تیتر موتوری — همیشه رندر می‌شود؛ داخل ناحیه امن استاتوس‌بار""")

# ۷) بدون چت حباب در منو — مغز فقط برای نفس‌کشیدن
rep("""func _deco_brain() -> void:
        brain = BRAIN_SCRIPT.new()
        add_child(brain)
        # گپ زدن خودکار ماشین‌ها — روح طنز منو (مثل v0.9)
        if deco_cars.size() >= 5:
                brain.start_idle_chatter(
                        func(cid: String) -> Control:
                                if cid == "boghi" and is_instance_valid(deco_cars[1]):
                                        return deco_cars[1]
                                if cid == "pride" and is_instance_valid(deco_cars[4]):
                                        return deco_cars[4]
                                return null,
                        func() -> Array: return ["boghi", "pride"], 8.0, 15.0)""",
"""func _deco_brain() -> void:
        brain = BRAIN_SCRIPT.new()
        add_child(brain)
        # حباب حرف در منو حذف شد — لحن جدی‌تر؛ مغز فقط نفس‌کشیدن را می‌دهد""")

open(P, "w", encoding="utf-8").write(src)
print("menu.gd patched OK")
