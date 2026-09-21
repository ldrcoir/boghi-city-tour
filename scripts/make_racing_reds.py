#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ماشین‌های مسابقه‌ای قرمز — درخواست کاربر
۱) دنا مسابقه‌ای قرمز  (از dena_side سفید → رنگ قرمز آتشین + استریک سفید)
۲) پژو ۲۰۶ مسابقه‌ای قرمز (از pejo_side نقره‌ای → قرمز + استریک)
روش: رنگ‌آمیزی ضربی پیکسل‌های بدن روشن (سفید/نقره‌ای) — سایه‌ها حفظ می‌شود
پنجره‌ها/چرخ‌ها/چراغ‌ها دست‌نخورده + لکه‌زدایی ملایم
"""
from PIL import Image, ImageFilter
import colorsys, os

BASE = "/home/z/my-project/game/assets/sprites"

# ضریب ضربی قرمز آتشین (R بالا، G/B پایین) — روی بدنه سفید/نقره‌ای سایه‌دار
RED_MULT = (1.00, 0.22, 0.18)

def is_body(px):
    """بدنه روشن خنثی: سفید/نقره‌ای — پنجره تیره و چرخ سیاه و چراغ زرد را نمی‌گیرد"""
    r, g, b, a = px
    if a < 40:
        return False
    mx, mn = max(r, g, b), min(r, g, b)
    v = mx / 255.0
    s = 0.0 if mx == 0 else (mx - mn) / mx
    # خنثی و به‌قدر کافی روشن؛ خیلی روشن (چراغ/هایلایت) را هم نگه می‌داریم ولی کم‌رنگ‌تر
    return s < 0.30 and v > 0.45

def is_dark(px):
    r, g, b, a = px
    mx = max(r, g, b)
    return a < 40 or mx < 90  # پنجره، لاستیک، قاب تیره

def tint_red(img):
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if not is_body((r, g, b, a)):
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            v = mx / 255.0
            # هایلایت خیلی داغ (V>0.93) کم‌رنگ‌تر رنگ می‌گیرد تا چراغ/برق بدنه زنده بماند
            k = 0.55 if v > 0.93 else 1.0
            nr = min(255, int(r * RED_MULT[0]))
            ng = min(255, int(g * RED_MULT[1] * (1 - k) + g * k))
            nb = min(255, int(b * RED_MULT[2] * (1 - k) + b * k))
            src[x, y] = (nr, ng, nb, a)
    return img

def add_stripes(img):
    """دو استریک مسابقه‌ای سفید روی بدنه قرمز — فقط پیکسل‌های قرمز، بدون پنجره/چرخ"""
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    # باند استریک: روی خط کمربند بدنه (ارتفاع میانی بدنه، بالای چرخ‌ها)
    y0a, y1a = int(h * 0.46), int(h * 0.535)
    y0b, y1b = int(h * 0.575), int(h * 0.65)
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a < 40 or is_dark((r, g, b, a)):
                continue
            # فقط پیکسل‌های قرمزِ این بندها (بعد از tint قرمزاند)
            in_band = (y0a <= y <= y1a) or (y0b <= y <= y1b)
            if not in_band:
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            s = 0.0 if mx == 0 else (mx - mn) / mx
            v = mx / 255.0
            if r > 120 and r > g and r > b and s > 0.35 and v > 0.25:
                # مخلوط با سفید — سایه حفظ شود
                k = 0.55
                nr = int(r + (255 - r) * k)
                ng = int(g + (255 - g) * k)
                nb = int(b + (255 - b) * k)
                src[x, y] = (nr, ng, nb, a)
    return img

def despeckle(img, thr=90, rad=2):
    """لکه‌های تیره نویز روی بدنه روشن → میانگین همسایه"""
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    fixes = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a < 40:
                continue
            mx = max(r, g, b)
            if mx < thr and max(r,g,b)-min(r,g,b) < 40:  # خاکستری تیره = نویز
                fixes.append((x, y))
    for (x, y) in fixes:
        rs = gs = bs = as_ = n = 0
        for dy in range(-rad, rad + 1):
            for dx in range(-rad, rad + 1):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h:
                    r2, g2, b2, a2 = src[xx, yy]
                    if a2 > 40 and max(r2, g2, b2) >= thr:
                        rs += r2; gs += g2; bs += b2; as_ += a2; n += 1
        if n > 0:
            src[x, y] = (rs // n, gs // n, bs // n, as_ // n)
    return img

def strip_fringe(img):
    """حذف هاله صورتی/ماژنتای لبه (کروماکی قدیمی)"""
    img = img.convert("RGBA")
    src = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a > 0 and r > 150 and b > 150 and g < r * 0.55 and g < b * 0.55:
                src[x, y] = (r, g, b, 0)
    return img

jobs = [
    ("dena_side.png", "dena_race_side.png"),
    ("pejo_side.png", "pejo_race_side.png"),
]
for src_name, out_name in jobs:
    im = Image.open(os.path.join(BASE, src_name))
    print(src_name, im.size, im.mode)
    im = strip_fringe(im)
    im = tint_red(im)
    im = add_stripes(im)
    im = despeckle(im)
    out = os.path.join(BASE, out_name)
    im.save(out)
    print("saved", out)
print("RACING REDS DONE")
