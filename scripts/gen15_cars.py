#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen15_cars — نسل جدید اسپرایت ماشین از بالا (top-down) برای بوقی v0.15
ماشین‌ها رو به راست (+X) رسم می‌شوند؛ نسبت واقعی ~2.3:1؛ سوپرسمپل 4x + LANCZOS.
هر ماشین: سیلوئت واقعی (کاپوت/کابین/صندوق)، شیشه با انعکاس، خط درز،
چراغ جلو گرم/چراغ عقب سرخ، آینه، سپر، لاستیک، رینگ — بدون چشم، بدون کارتون."""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "/home/z/my-project/game/assets/sprites"
SS = 4                      # سوپرسمپل
L = 152                     # طول نهایی بر حسب پیکسلِ دنیا
W = 66                      # عرض نهایی

def _P(v):                  # مقیاس سوپرسمپل
    return v * SS

def body_profile(t, style):
    """پهنای بدنه در طول ماشین t∈[0..1] (جلو=0) — کلاف واقعی خودرو."""
    if style == "coupe":
        k = [0.50, 0.72, 0.90, 0.97, 1.00, 0.99, 0.96, 0.97, 1.00, 0.94, 0.82, 0.66, 0.46]
    elif style == "sedan":
        k = [0.46, 0.72, 0.92, 1.00, 0.98, 0.96, 0.95, 0.97, 1.00, 0.97, 0.92, 0.74, 0.50]
    elif style == "hatch":
        k = [0.44, 0.74, 0.93, 1.00, 0.97, 0.94, 0.95, 0.98, 1.00, 0.99, 0.97, 0.90, 0.78]
    elif style == "muscle":
        k = [0.54, 0.78, 0.94, 1.00, 0.98, 0.96, 0.96, 0.98, 1.00, 0.98, 0.94, 0.78, 0.56]
    elif style == "van":
        k = [0.60, 0.90, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 0.98, 0.92]
    else:  # sedan
        k = [0.46, 0.72, 0.92, 1.00, 0.98, 0.96, 0.95, 0.97, 1.00, 0.97, 0.92, 0.74, 0.50]
    x = t * (len(k) - 1)
    i = min(int(x), len(k) - 2)
    f = x - i
    return (k[i] * (1 - f) + k[i + 1] * f)

def make_car(spec):
    """یک اسپرایت ماشین کامل می‌سازد و برمی‌گرداند (RGB با آلفا)."""
    rnd = random.Random(spec.get("seed", 7))
    style = spec["style"]
    base = spec["base"]
    dark = spec.get("dark", tuple(int(c * 0.62) for c in base))
    lite = spec.get("lite", tuple(min(255, int(c * 1.35 + 24)) for c in base))
    roofc = spec.get("roof", tuple(int(c * 0.55) for c in base))
    glass = spec.get("glass", (16, 20, 30))
    cw, ch = _P(L + 24), _P(W + 24)
    img = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = cw / 2, ch / 2
    hl, hw = _P(L), _P(W)

    def px(t):  # موقعیت طولی → x
        return cx - hl / 2 + t * hl

    # ── لاستیک‌ها (زیر بدنه، کمی بیرون می‌زنند — فقط فرمول کاملاً بیرون است)
    ax_f, ax_r = px(0.205), px(0.795)
    for ax in (ax_f, ax_r):
        for sgn in (-1, 1):
            wy = cy + sgn * (hw / 2 - _P(4))
            if spec.get("exposed_wheels"):
                wy = cy + sgn * (hw / 2 + _P(2))
            d.rounded_rectangle([ax - _P(15), wy - _P(7.5), ax + _P(15), wy + _P(7.5)],
                                radius=_P(5), fill=(8, 8, 11, 255))

    # ── سیلوئت بدنه از پروفایل
    N = 72
    top, bot = [], []
    for i in range(N + 1):
        t = i / N
        w = body_profile(t, style) * hw / 2
        top.append((px(t), cy - w))
        bot.append((px(t), cy + w))
    sil = top + bot[::-1]
    d.polygon(sil, fill=base + (255,))

    # ── گرادیان عرضی (سقف روشن‌تر، پهلو تیره‌تر) + سایش مرکز
    grad = np.zeros((ch, cw, 4), dtype=np.float32)
    body_mask = Image.new("L", (cw, ch), 0)
    ImageDraw.Draw(body_mask).polygon(sil, fill=255)
    bm = np.asarray(body_mask, dtype=np.float32) / 255.0
    yy = np.linspace(-1, 1, ch, dtype=np.float32)[:, None]
    shade = np.clip(1.0 - 0.34 * (yy ** 2), 0.55, 1.06)
    for c in range(3):
        col = np.array(base[c], dtype=np.float32)
        col2 = np.array(lite[c], dtype=np.float32)
        g = col + (col2 - col) * np.clip((1.0 - abs(yy)) * 0.9, 0, 1)
        grad[:, :, c] = np.clip(g * shade * bm, 0, 255)
    grad[:, :, 3] = bm * 255
    img = Image.alpha_composite(img, Image.fromarray(grad.astype(np.uint8), "RGBA"))
    d = ImageDraw.Draw(img)

    # ── کابین/شیشه‌ها — موقعیت بر اساس سبک
    cab0, cab1 = {"coupe": (0.40, 0.70), "sedan": (0.36, 0.72), "hatch": (0.34, 0.68),
                  "muscle": (0.38, 0.68), "van": (0.22, 0.60)}.get(style, (0.36, 0.72))
    if style == "van":
        cab0, cab1 = 0.20, 0.42
    cabw = 0.80  # کابین کمی باریک‌تر از بدنه
    top2, bot2 = [], []
    for i in range(25):
        t = cab0 + (cab1 - cab0) * i / 24
        w = body_profile(t, style) * hw / 2 * cabw
        top2.append((px(t), cy - w))
        bot2.append((px(t), cy + w))
    glass_poly = top2 + bot2[::-1]
    d.polygon(glass_poly, fill=glass + (255,))
    # سقف — بین شیشه جلو و عقب
    rf0, rf1 = cab0 + 0.075, cab1 - 0.075
    top3, bot3 = [], []
    for i in range(21):
        t = rf0 + (rf1 - rf0) * i / 20
        w = body_profile(t, style) * hw / 2 * cabw
        top3.append((px(t), cy - w))
        bot3.append((px(t), cy + w))
    d.polygon(top3 + bot3[::-1], fill=roofc + (255,))
    # انعکاس مورب روی شیشه
    refl = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    dr = ImageDraw.Draw(refl)
    for k in range(3):
        xo = _P(20 + k * 16)
        dr.line([(px(cab0) + xo, cy - hw / 2), (px(cab0) + xo - _P(26), cy + hw / 2)],
                fill=(255, 255, 255, 26), width=_P(4))
    refl = refl.filter(ImageFilter.GaussianBlur(_P(2)))
    mask2 = Image.new("L", (cw, ch), 0)
    ImageDraw.Draw(mask2).polygon(glass_poly, fill=110)
    img.paste(Image.alpha_composite(img.crop((0, 0, cw, ch)), refl), (0, 0), Image.composite(refl.split()[3], Image.new("L", (cw, ch), 0), mask2))
    d = ImageDraw.Draw(img)

    # ── درزها و جزئیات
    seam = tuple(max(0, c - 40) for c in dark) + (150,)
    for t in (cab0 - 0.012, cab1 + 0.012):   # درز کاپوت/صندوق
        w = body_profile(t, style) * hw / 2
        d.line([(px(t), cy - w + _P(2)), (px(t), cy + w - _P(2))], fill=seam, width=SS)
    for sgn in (-1, 1):                       # خط پهلو
        d.line([(px(0.10), cy + sgn * hw * 0.44), (px(0.94), cy + sgn * hw * 0.40)],
               fill=seam, width=SS)
    # آینه‌ها
    for sgn in (-1, 1):
        d.rounded_rectangle([px(cab0) - _P(4), cy + sgn * (hw / 2 + _P(1)) - _P(5),
                             px(cab0) + _P(6), cy + sgn * (hw / 2 + _P(1)) + _P(5)],
                            radius=_P(2), fill=dark + (255,))

    # ── نوار رگلی / لivery
    if spec.get("stripe"):
        sc = spec["stripe"]
        for off in (-_P(6), _P(6)):
            d.line([(px(0.03), cy + off), (px(0.99), cy + off)],
                   fill=sc + (235,), width=_P(5))
    if spec.get("livery"):
        lc = spec["livery"]
        for sgn in (-1, 1):
            d.polygon([(px(0.06), cy + sgn * hw * 0.30), (px(0.34), cy + sgn * hw * 0.34),
                       (px(0.30), cy + sgn * hw * 0.46), (px(0.04), cy + sgn * hw * 0.42)],
                      fill=lc + (255,))

    # ── ورودی هوای کاپوت (اسپرت)
    if spec.get("scoop"):
        d.rounded_rectangle([px(0.14), cy - _P(9), px(0.26), cy + _P(9)],
                            radius=_P(4), fill=(14, 14, 18, 255))
        d.rounded_rectangle([px(0.15), cy - _P(6), px(0.25), cy + _P(6)],
                            radius=_P(3), fill=(30, 30, 38, 255))
    # هود کربنی
    if spec.get("carbon_hood"):
        hmask = Image.new("L", (cw, ch), 0)
        hp = []
        for i in range(21):
            t = 0.03 + (cab0 - 0.03) * i / 20
            w = body_profile(t, style) * hw / 2
            hp.append((px(t), cy - w))
            hp.insert(0, (px(t), cy + w))
        ImageDraw.Draw(hmask).polygon(hp, fill=70)
        carbon = Image.new("RGBA", (cw, ch), (22, 22, 27, 255))
        arr = np.asarray(carbon, dtype=np.uint8).copy()
        chk = (np.add.outer(np.arange(ch) // _P(3), np.arange(cw) // _P(3)) % 2).astype(np.uint8) * 14
        arr[:, :, 0] = np.clip(arr[:, :, 0] + chk, 0, 255)
        arr[:, :, 1] = np.clip(arr[:, :, 1] + chk, 0, 255)
        carbon = Image.fromarray(arr)
        img.paste(carbon, (0, 0), hmask)
        d = ImageDraw.Draw(img)

    # ── چراغ جلو (گرم) + نوار روز
    hx0, hx1 = px(0.005), px(0.055)
    for sgn in (-1, 1):
        wy = cy + sgn * hw * 0.27
        d.rounded_rectangle([hx0, min(wy, cy) - _P(7) if sgn < 0 else wy - _P(7),
                             hx1, wy + _P(7)], radius=_P(3), fill=(255, 244, 205, 255))
    d.line([(hx0 + _P(2), cy - hw * 0.16), (hx0 + _P(2), cy + hw * 0.16)],
           fill=(255, 240, 190, 200), width=_P(2))
    # ── چراغ عقب سرخ
    tx0, tx1 = px(0.955), px(0.995)
    for sgn in (-1, 1):
        wy = cy + sgn * hw * 0.28
        d.rounded_rectangle([tx0, wy - _P(7), tx1, wy + _P(7)],
                            radius=_P(3), fill=(225, 42, 36, 255))
    d.line([(tx1 - _P(1), cy - hw * 0.20), (tx1 - _P(1), cy + hw * 0.20)],
           fill=(255, 70, 55, 230), width=_P(2))
    # اگزوز
    for sgn in (-1, 1):
        d.ellipse([px(0.985) - _P(3), cy + sgn * hw * 0.12 - _P(3),
                   px(0.985) + _P(3), cy + sgn * hw * 0.12 + _P(3)], fill=(20, 20, 24, 255))

    # ── اسپویلر / وینگ
    if spec.get("wing"):
        wc = spec.get("wing_col", (18, 18, 23))
        d.rounded_rectangle([px(0.955), cy - hw / 2 - _P(3), px(0.99), cy + hw / 2 + _P(3)],
                            radius=_P(3), fill=wc + (255,))
        d.line([(px(0.93), cy - hw * 0.2), (px(0.955), cy - hw * 0.2)], fill=wc + (255,), width=_P(3))
        d.line([(px(0.93), cy + hw * 0.2), (px(0.955), cy + hw * 0.2)], fill=wc + (255,), width=_P(3))

    # ── شماره‌ی رگلی روی سقف
    if spec.get("num"):
        r = _P(13)
        npos = (px((cab0 + cab1) / 2), cy)
        d.ellipse([npos[0] - r, npos[1] - r, npos[0] + r, npos[1] + r], fill=(245, 245, 248, 255))
        try:
            f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", _P(17))
            d.text(npos, str(spec["num"]), font=f, fill=(20, 20, 26), anchor="mm")
        except Exception:
            pass

    # ── پلاک/جرم‌های کوچک
    d.rounded_rectangle([px(0.005), cy - _P(6), px(0.02), cy + _P(6)], radius=_P(1),
                        fill=(200, 200, 205, 255))
    # هایلایت مرکزی نرم
    sheen = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sheen)
    ds.ellipse([cx - hl * 0.42, cy - hw * 0.34, cx + hl * 0.42, cy + hw * 0.34],
               fill=(255, 255, 255, 22))
    sheen = sheen.filter(ImageFilter.GaussianBlur(_P(8)))
    img = Image.alpha_composite(img, sheen)

    # ── خط دور بدنه
    d.line(sil + [sil[0]], fill=tuple(max(0, c - 55) for c in base) + (200,), width=SS, joint="curve")

    # ── فرمول: بال جلو + چرخ‌های بیرون‌زده رسم شده‌اند؛ بال عقب
    return img

def formula_car(spec):
    """ماشین فرمول — بدنه باریک، چرخ باز، بال جلو/عقب."""
    rnd = random.Random(spec.get("seed", 3))
    base = spec["base"]
    cw, ch = _P(L + 24), _P(W + 44)
    img = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = cw / 2, ch / 2
    hl = _P(L)
    def px(t): return cx - hl / 2 + t * hl
    # چرخ‌ها
    for ax in (px(0.16), px(0.80)):
        for sgn in (-1, 1):
            wy = cy + sgn * _P(19)
            d.ellipse([ax - _P(16), wy - _P(15), ax + _P(16), wy + _P(15)], fill=(10, 10, 13, 255))
            d.ellipse([ax - _P(8), wy - _P(8), ax + _P(8), wy + _P(8)], fill=(48, 48, 56, 255))
            d.ellipse([ax - _P(3), wy - _P(3), ax + _P(3), wy + _P(3)], fill=(120, 122, 132, 255))
    # بال جلو
    d.rounded_rectangle([px(0.01), cy - _P(21), px(0.075), cy + _P(21)], radius=_P(3),
                        fill=base + (255,))
    d.rounded_rectangle([px(0.01), cy - _P(21), px(0.03), cy + _P(21)], radius=_P(2),
                        fill=(20, 20, 26, 255))
    # بدنه‌ی باریک
    body = [(px(0.06), cy - _P(7)), (px(0.30), cy - _P(10)), (px(0.72), cy - _P(11)),
            (px(0.93), cy - _P(13)), (px(0.93), cy + _P(13)), (px(0.72), cy + _P(11)),
            (px(0.30), cy + _P(10)), (px(0.06), cy + _P(7))]
    d.polygon(body, fill=base + (255,))
    # کاکپیت + هالو
    d.polygon([(px(0.34), cy - _P(7)), (px(0.55), cy - _P(8)), (px(0.55), cy + _P(8)),
               (px(0.34), cy + _P(7))], fill=(14, 16, 24, 255))
    d.arc([px(0.40), cy - _P(12), px(0.58), cy + _P(12)], 200, 340, fill=(30, 30, 38, 255), width=_P(3))
    # موتور/ایرفوی
    d.polygon([(px(0.58), cy - _P(6)), (px(0.75), cy - _P(4)), (px(0.75), cy + _P(4)),
               (px(0.58), cy + _P(6))], fill=tuple(int(c * 0.7) for c in base) + (255,))
    # بال عقب
    d.rounded_rectangle([px(0.93), cy - _P(20), px(0.985), cy + _P(20)], radius=_P(3),
                        fill=base + (255,))
    d.rounded_rectangle([px(0.985), cy - _P(20), px(0.995), cy + _P(20)], radius=_P(2),
                        fill=(20, 20, 26, 255))
    # شماره
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", _P(13))
        d.text((px(0.24), cy), str(spec.get("num", 7)), font=f, fill=(250, 250, 252), anchor="mm")
    except Exception:
        pass
    return img

# ─────────── جدول ماشین‌ها ───────────
CARS = {
    # قهرمان — کوپه‌ی نارنجی آتشی با هود کربن (بوقی)
    "boghi":        {"style": "coupe", "base": (226, 74, 32), "carbon_hood": True, "stripe": (24, 22, 22), "seed": 2},
    "boghi_yellow": {"style": "coupe", "base": (238, 190, 48), "stripe": (26, 24, 20), "seed": 3},
    "tiba":         {"style": "hatch", "base": (150, 168, 182), "seed": 4},
    "pride":        {"style": "hatch", "base": (196, 44, 38), "seed": 5},
    "pejo":         {"style": "hatch", "base": (168, 178, 160), "seed": 6},
    "samand":       {"style": "sedan", "base": (96, 104, 118), "seed": 7},
    "dena":         {"style": "sedan", "base": (142, 40, 44), "seed": 8},
    "nissan":       {"style": "muscle", "base": (86, 108, 132), "seed": 9},
    "pejo_race":    {"style": "hatch", "base": (232, 232, 238), "livery": (226, 60, 40), "wing": True, "num": 21, "seed": 10},
    "shahin":       {"style": "sedan", "base": (44, 118, 128), "seed": 11},
    "quick":        {"style": "hatch", "base": (168, 214, 60), "seed": 12},
    "dena_race":    {"style": "sedan", "base": (30, 30, 36), "stripe": (226, 50, 40), "wing": True, "num": 8, "seed": 13},
    "pride_blue":   {"style": "hatch", "base": (40, 92, 200), "stripe": (240, 240, 246), "wing": True, "num": 14, "seed": 14},
    "pejo_green":   {"style": "hatch", "base": (36, 148, 92), "stripe": (240, 240, 246), "wing": True, "num": 33, "seed": 15},
    "shahin_white": {"style": "sedan", "base": (222, 226, 232), "roof": (120, 124, 134), "seed": 16},
    "dena_red":     {"style": "sedan", "base": (188, 34, 40), "roof": (60, 18, 18), "seed": 17},
    "nissan_blue":  {"style": "muscle", "base": (44, 84, 178), "stripe": (250, 250, 250), "seed": 18},
    "formula_red":  {"style": "formula", "base": (222, 46, 36), "num": 1, "seed": 19},
    "formula_blue": {"style": "formula", "base": (36, 96, 216), "num": 7, "seed": 20},
    "formula_black":{"style": "formula", "base": (34, 34, 42), "num": 0, "seed": 21},
    # ترافیک
    "traf_white":   {"style": "sedan", "base": (208, 210, 214), "seed": 22},
    "traf_gray":    {"style": "sedan", "base": (118, 124, 134), "seed": 23},
    "traf_taxi":    {"style": "sedan", "base": (226, 178, 32), "seed": 24},
    "traf_van":     {"style": "van", "base": (198, 200, 206), "seed": 25},
}

def main():
    os.makedirs(OUT, exist_ok=True)
    for cid, spec in CARS.items():
        if spec["style"] == "formula":
            img = formula_car(spec)
        else:
            img = make_car(spec)
        if cid == "traf_taxi":
            # تابلو و شطرنجی تاکسی
            d = ImageDraw.Draw(img)
            cw, ch = img.size
            cx, cy = cw / 2, ch / 2
            sc = SS
            d.rounded_rectangle([cx - _P(11), cy - _P(8), cx + _P(11), cy + _P(8)],
                                radius=_P(2), fill=(40, 40, 44, 255))
            d.rectangle([cx - _P(9), cy - _P(6), cx + _P(9), cy + _P(6)], fill=(255, 214, 64, 255))
            try:
                f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", _P(9))
                d.text((cx, cy), "TAXI", font=f, fill=(30, 26, 10), anchor="mm")
            except Exception:
                pass
        fw, fh = img.size
        fin = img.resize((fw // SS, fh // SS), Image.LANCZOS)
        fin.save(os.path.join(OUT, cid + "_top.png"))
        print("car:", cid, fin.size)
    # شیت پیش‌نمایش برای بازبینی خودم
    cols, rows = 7, 4
    tw, th = 200, 120
    sheet = Image.new("RGB", (cols * tw, rows * th), (16, 18, 26))
    sd = ImageDraw.Draw(sheet)
    for i, cid in enumerate(CARS):
        x = (i % cols) * tw + (tw - 176) // 2
        y = (i // cols) * th + (th - 90) // 2
        car = Image.open(os.path.join(OUT, cid + "_top.png"))
        # ماشین رو به راست است؛ در شیت کمی بچرخانیم رو به بالا
        car = car.rotate(90, expand=True)
        sheet.paste(car, (x + (176 - car.size[0]) // 2, y + (90 - car.size[1]) // 2), car)
    sheet.save("/home/z/my-project/scripts/preview_cars.png")
    print("sheet saved")

if __name__ == "__main__":
    main()
