#!/usr/bin/env python3
"""Scene overhaul in game.gd (8-space indent file): bigger car, drop shadow,
warm backdrop, tree band fit."""
import re

P = "/home/z/my-project/game/scripts/game.gd"
src = open(P, encoding="utf-8").read()


def sub1(pat, repl, tag):
    global src
    m = re.search(pat, src)
    assert m, f"pattern not found: {tag}"
    src = src[:m.start()] + repl + src[m.end():]
    print("ok:", tag)


I8 = " " * 8

# 1) dark warm fallback behind everything
sub1(
    r'backdrop\.color = Color\(0\.99, 0\.9, 0\.78\)',
    'backdrop.color = Color(0.09, 0.07, 0.11) # پس‌زمینه تیره گرم — نسل ۲',
    "backdrop")

# 2) tree band squash for tall cutout
sub1(
    r'_add_layer\("res://assets/sprites/bg_mid\.png", -10, GROUND_Y \+ 30\.0, 1\.286, 0\.45, 0\.7\)',
    '_add_layer("res://assets/sprites/bg_mid.png", -10, GROUND_Y + 30.0, 1.286, 0.45, 0.40)',
    "bg_mid squash")

# 3) bigger car + ground shadow build
sub1(
    r'var sc := 0\.58[^\n]*\n\s+car_sprite\.scale = Vector2\(sc, sc\)\n\s+var th := car_sprite\.texture\.get_height\(\) \* sc\n\s+car_sprite\.position = Vector2\(0, 12\.0 - th \* 0\.5\)[^\n]*',
    (I8 + 'var sc := 0.68 # نسل ۲: ماشین واقعی و درشت در محیط (درخواست کاربر)\n'
      + I8 + 'car_sprite.scale = Vector2(sc, sc)\n'
      + I8 + 'var th := car_sprite.texture.get_height() * sc\n'
      + I8 + 'car_sprite.position = Vector2(0, 12.0 - th * 0.5) # چرخ‌ها روی جاده\n'
      + I8 + 'shadow = Sprite2D.new()\n'
      + I8 + 'shadow.texture = _make_shadow_tex()\n'
      + I8 + 'shadow.position = Vector2(0, -4)\n'
      + I8 + 'shadow.z_index = -1\n'
      + I8 + 'car.add_child(shadow)'),
    "car scale + shadow build")

# 4) shadow var
sub1(r'var car_sprite: Sprite2D', 'var car_sprite: Sprite2D\nvar shadow: Sprite2D', "shadow var")

# 5) collision fits bigger car (two separate lines, shape.shape sits between)
sub1(r'rect\.size = Vector2\(215, 145\)', I8 + 'rect.size = Vector2(235, 160)', "collision size")
sub1(r'shape\.position = Vector2\(0, -70\)', I8 + 'shape.position = Vector2(0, -78)', "collision pos")

# 6) shadow follows jump height
sub1(
    r'car\.position = Vector2\(CAR_X, GROUND_Y \+ car_y\)\n\s+car_sprite\.rotation = clamp\(vy \* 0\.00045, -0\.3, 0\.35\)',
    (I8 + 'car.position = Vector2(CAR_X, GROUND_Y + car_y)\n'
      + I8 + 'car_sprite.rotation = clamp(vy * 0.00045, -0.3, 0.35)\n'
      + I8 + 'var h := clamp(-car_y / 420.0, 0.0, 1.0)\n'
      + I8 + 'shadow.scale = Vector2(1.0 - 0.4 * h, 1.0 - 0.25 * h)\n'
      + I8 + 'shadow.modulate = Color(1, 1, 1, 0.5 - 0.32 * h)'),
    "shadow update")

# 7) soft ellipse shadow texture helper (spaces only — no tabs in this file)
src += "\n\nfunc _make_shadow_tex() -> ImageTexture:\n"
src += " " * 4 + "var sz := Vector2i(180, 56)\n"
src += " " * 4 + "var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)\n"
src += " " * 4 + "var cx := sz.x / 2.0\n"
src += " " * 4 + "var cy := sz.y / 2.0\n"
src += " " * 4 + "for y in sz.y:\n"
src += " " * 8 + "for x in sz.x:\n"
src += " " * 12 + "var d := Vector2((x - cx) / (cx - 6.0), (y - cy) / (cy - 4.0)).length()\n"
src += " " * 12 + "var a := clamp(1.0 - d, 0.0, 1.0)\n"
src += " " * 12 + "img.set_pixel(x, y, Color(0.03, 0.02, 0.05, a * a * 0.9))\n"
src += " " * 4 + "return ImageTexture.create_from_image(img)\n"

open(P, "w", encoding="utf-8").write(src)
print("game.gd patched OK")
