#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
تولید اسپرایت ماشین از بالا (top-down) — واقعی، بدون چشم، سبک شب.
این دیگر بازی کودکانه نیست: ماشین‌های واقعی خیابان ایران از نمای بالا.
هر ماشین: بدنه + کابین + شیشه + چراغ جلو (زرد) + چراغ عقب (قرمز) + لاستیک.
خروجی: game/assets/sprites/{id}_top.png  (رو به راست — rotation 0 = شرق)
"""
from PIL import Image, ImageDraw, ImageFilter
import os

OUT = "/home/z/my-project/game/assets/sprites"
os.makedirs(OUT, exist_ok=True)

# انواع بدنه: hatch / sedan / pickup / formula
SPECS = {
    "boghi":        ("hatch",  (200, 40, 40),  None),
    "boghi_yellow": ("hatch",  (235, 185, 40), None),
    "tiba":         ("hatch",  (90, 150, 210), None),
    "pride":        ("hatch",  (215, 55, 45),  (255, 255, 255)),
    "pejo":         ("sedan",  (178, 182, 190), None),
    "samand":       ("sedan",  (232, 230, 224), None),
    "dena":         ("sedan",  (240, 238, 232), None),
    "nissan":       ("pickup", (195, 60, 45),  None),
    "pejo_race":    ("hatch",  (220, 45, 40),  (255, 255, 255)),
    "shahin":       ("sedan",  (38, 38, 44),   (212, 175, 55)),
    "quick":        ("hatch",  (240, 130, 30), None),
    "dena_race":    ("sedan",  (238, 234, 228), (215, 40, 40)),
    "pride_blue":   ("hatch",  (55, 110, 220), (255, 255, 255)),
    "pejo_green":   ("hatch",  (40, 150, 95),  (25, 25, 28)),
    "shahin_white": ("sedan",  (235, 235, 238), (212, 175, 55)),
    "dena_red":     ("sedan",  (185, 35, 35),  None),
    "nissan_blue":  ("pickup", (60, 105, 200), None),
    "formula_red":  ("formula",(210, 45, 40),  (255, 255, 255)),
    "formula_blue": ("formula",(55, 120, 225), (255, 255, 255)),
    "formula_black":("formula",(32, 32, 38),   (212, 175, 55)),
}

SS = 2  # supersample

def rounded(d, box, r, fill):
    d.rounded_rectangle(box, radius=r, fill=fill)

def make_car(body, col, stripe):
    W, H = 168 * SS, 84 * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = W // 2, H // 2

    bb = None
    if body == "formula":
        L, Wd = 160 * SS, 34 * SS          # بدنه باریک
        bb = [cx - L // 2, cy - Wd // 2, cx + L // 2, cy + Wd // 2]
        wheel_w, wheel_h = 26 * SS, 12 * SS
        wing_w, wing_h = 56 * SS, 10 * SS
        dark = tuple(int(c * 0.55) for c in col)
        # بال عقب و جلو
        d.rounded_rectangle([cx - L // 2, cy - wing_h, cx - L // 2 + 14 * SS, cy + wing_h], 4 * SS, fill=dark)
        d.rounded_rectangle([cx + L // 2 - 14 * SS, cy - wing_h, cx + L // 2, cy + wing_h], 4 * SS, fill=dark)
        # چرخ‌های بیرون‌زده
        for wx in (-52, 40):
            for wy in (-1, 1):
                d.rounded_rectangle([cx + wx * SS - wheel_w // 2, cy + wy * (Wd // 2 + 2 * SS) - wheel_h // 2,
                                     cx + wx * SS + wheel_w // 2, cy + wy * (Wd // 2 + 2 * SS) + wheel_h // 2],
                                    3 * SS, fill=(22, 22, 26, 255))
        rounded(d, [cx - L // 2, cy - Wd // 2, cx + L // 2, cy + Wd // 2], 8 * SS, col + (255,))
        # کابین خلبان
        rounded(d, [cx - 4 * SS, cy - 12 * SS, cx + 22 * SS, cy + 12 * SS], 6 * SS, (30, 30, 36, 255))
        rounded(d, [cx + 22 * SS, cy - 9 * SS, cx + 30 * SS, cy + 9 * SS], 4 * SS, (120, 160, 190, 255))
        # هواکش
        d.rectangle([cx - 30 * SS, cy - 8 * SS, cx - 24 * SS, cy + 8 * SS], fill=(20, 20, 24, 255))
        stripe_c = stripe or (255, 255, 255)
        d.rectangle([cx - L // 2 + 12 * SS, cy - 3 * SS, cx + L // 2 - 16 * SS, cy + 3 * SS], fill=stripe_c + (230,))
    elif body == "pickup":
        L, Wd = 162 * SS, 68 * SS
        bb = [cx - L // 2, cy - Wd // 2, cx + L // 2, cy + Wd // 2]
        cab_l = 34 * SS   # طول کابین
        bed_l = L // 2 - 6 * SS  # وانت
        dark = tuple(int(c * 0.62) for c in col)
        # چرخ‌ها
        for wx in (-46, 44):
            for wy in (-1, 1):
                d.rounded_rectangle([cx + wx * SS - 15 * SS, cy + wy * (Wd // 2 - 3 * SS) - 6 * SS,
                                     cx + wx * SS + 15 * SS, cy + wy * (Wd // 2 - 3 * SS) + 6 * SS],
                                    4 * SS, fill=(20, 20, 24, 255))
        # بدنه کلی
        rounded(d, [cx - L // 2, cy - Wd // 2, cx + L // 2, cy + Wd // 2], 10 * SS, col + (255,))
        # وانت باز (تیره با لبه)
        rounded(d, [cx - L // 2 + 8 * SS, cy - Wd // 2 + 7 * SS, cx - L // 2 + 8 * SS + bed_l, cy + Wd // 2 - 7 * SS],
                6 * SS, (46, 44, 48, 255))
        d.rectangle([cx - L // 2 + 8 * SS + bed_l - 3 * SS, cy - Wd // 2 + 7 * SS,
                     cx - L // 2 + 8 * SS + bed_l, cy + Wd // 2 - 7 * SS], fill=dark + (255,))
        # کابین
        rounded(d, [cx + 8 * SS, cy - Wd // 2 + 6 * SS, cx + 8 * SS + cab_l, cy + Wd // 2 - 6 * SS],
                8 * SS, dark + (255,))
        # شیشه جلو و سقف
        rounded(d, [cx + 8 * SS + cab_l - 9 * SS, cy - Wd // 2 + 9 * SS, cx + 8 * SS + cab_l - 2 * SS, cy + Wd // 2 - 9 * SS],
                3 * SS, (125, 165, 195, 255))
        rounded(d, [cx + 14 * SS, cy - Wd // 2 + 9 * SS, cx + 8 * SS + cab_l - 12 * SS, cy + Wd // 2 - 9 * SS],
                4 * SS, (25, 25, 30, 255))
        # گلگیر جلو
        rounded(d, [cx + L // 2 - 52 * SS, cy - Wd // 2 + 8 * SS, cx + L // 2 - 4 * SS, cy + Wd // 2 - 8 * SS],
                8 * SS, col + (255,))
        d.line([cx + L // 2 - 52 * SS, cy, cx + L // 2 - 4 * SS, cy], fill=dark + (180,), width=2 * SS)
    else:
        L = 158 * SS if body == "sedan" else 146 * SS
        Wd = 70 * SS
        dark = tuple(int(c * 0.62) for c in col)
        lite = tuple(min(255, int(c * 1.18)) for c in col)
        # چرخ‌ها
        for wx in (-46, 46):
            for wy in (-1, 1):
                d.rounded_rectangle([cx + wx * SS - 16 * SS, cy + wy * (Wd // 2 - 2 * SS) - 6 * SS,
                                     cx + wx * SS + 16 * SS, cy + wy * (Wd // 2 - 2 * SS) + 6 * SS],
                                    4 * SS, fill=(20, 20, 24, 255))
        # بدنه با دماغه باریک‌تر (پلی‌گان ملایم)
        bb = [cx - L // 2 + 6 * SS, cy - Wd // 2, cx + L // 2 - 2 * SS, cy + Wd // 2]
        rounded(d, bb, 14 * SS, col + (255,))
        # تیرگی لبه‌ها (حجم)
        rounded(d, [bb[0] + 3 * SS, bb[1] + 4 * SS, bb[2] - 3 * SS, bb[3] - 4 * SS], 11 * SS, lite + (60,))
        # کاپوت و صندوق — خطوط بدنه
        d.line([bb[0] + 30 * SS, bb[1] + 6 * SS, bb[0] + 30 * SS, bb[3] - 6 * SS], fill=dark + (150,), width=2 * SS)
        d.line([bb[2] - 26 * SS, bb[1] + 6 * SS, bb[2] - 26 * SS, bb[3] - 6 * SS], fill=dark + (150,), width=2 * SS)
        # کابین
        if body == "sedan":
            cab = [cx - 40 * SS, cy - Wd // 2 + 8 * SS, cx + 34 * SS, cy + Wd // 2 - 8 * SS]
        else:
            cab = [cx - 30 * SS, cy - Wd // 2 + 8 * SS, cx + 34 * SS, cy + Wd // 2 - 8 * SS]
        rounded(d, cab, 10 * SS, dark + (255,))
        # شیشه جلو (تراپزوئید رو به جلو)
        d.polygon([(cab[2], cy - Wd // 2 + 11 * SS), (cab[2] + 12 * SS, cy - Wd // 2 + 16 * SS),
                   (cab[2] + 12 * SS, cy + Wd // 2 - 16 * SS), (cab[2], cy + Wd // 2 - 11 * SS)],
                  fill=(128, 168, 198, 255))
        # شیشه عقب
        d.polygon([(cab[0], cy - Wd // 2 + 12 * SS), (cab[0] - 9 * SS, cy - Wd // 2 + 17 * SS),
                   (cab[0] - 9 * SS, cy + Wd // 2 - 17 * SS), (cab[0], cy + Wd // 2 - 12 * SS)],
                  fill=(105, 140, 168, 255))
        # سقف (وسط کابین)
        rounded(d, [cab[0] + 8 * SS, cab[1] + 4 * SS, cab[2] - 8 * SS, cab[3] - 4 * SS], 8 * SS,
                tuple(int(c * 0.8) for c in col) + (255,))
        # آینه‌ها
        d.rectangle([cab[2] - 4 * SS, cy - Wd // 2 - 1 * SS, cab[2] + 4 * SS, cy - Wd // 2 + 4 * SS], fill=dark + (255,))
        d.rectangle([cab[2] - 4 * SS, cy + Wd // 2 - 4 * SS, cab[2] + 4 * SS, cy + Wd // 2 + 1 * SS], fill=dark + (255,))
        # استریک
        if stripe:
            d.rectangle([bb[0] + 8 * SS, cy - 4 * SS, bb[2] - 8 * SS, cy + 4 * SS], fill=stripe + (235,))
    # چراغ جلو — زرد گرم (دو نقطه + هاله)
    fx = bb[2] - 4 * SS if body != "formula" else cx + L // 2 - 3 * SS
    fy0, fy1 = cy - 16 * SS, cy + 16 * SS
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dg = ImageDraw.Draw(glow)
    dg.ellipse([fx - 14 * SS, fy0 - 12 * SS, fx + 14 * SS, fy0 + 12 * SS], fill=(255, 240, 170, 110))
    dg.ellipse([fx - 14 * SS, fy1 - 12 * SS, fx + 14 * SS, fy1 + 12 * SS], fill=(255, 240, 170, 110))
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    d.ellipse([fx - 5 * SS, fy0 - 4 * SS, fx + 5 * SS, fy0 + 4 * SS], fill=(255, 245, 190, 255))
    d.ellipse([fx - 5 * SS, fy1 - 4 * SS, fx + 5 * SS, fy1 + 4 * SS], fill=(255, 245, 190, 255))
    # چراغ عقب — قرمز
    rx = bb[0] + 3 * SS if body != "formula" else cx - L // 2 + 3 * SS
    d.rounded_rectangle([rx - 3 * SS, fy0 - 4 * SS, rx + 5 * SS, fy0 + 4 * SS], 2 * SS, fill=(255, 60, 40, 255))
    d.rounded_rectangle([rx - 3 * SS, fy1 - 4 * SS, rx + 5 * SS, fy1 + 4 * SS], 2 * SS, fill=(255, 60, 40, 255))

    img = img.resize((W // SS, H // SS), Image.LANCZOS)
    return img

for cid, (body, col, stripe) in SPECS.items():
    img = make_car(body, col, stripe)
    img.save(f"{OUT}/{cid}_top.png")
    print("OK", cid, img.size)

# اسپرایت ترافیک — رنگ‌های خنثی خیابانی + تاکسی
TRAF = {
    "traf_white": ("sedan", (210, 210, 214), None),
    "traf_gray":  ("sedan", (120, 124, 132), None),
    "traf_taxi":  ("sedan", (225, 190, 50),  (30, 30, 30)),
    "traf_van":   ("pickup", (170, 175, 182), None),
}
for cid, (body, col, stripe) in TRAF.items():
    img = make_car(body, col, stripe)
    img.save(f"{OUT}/{cid}_top.png")
    print("OK", cid, img.size)
print("DONE")
