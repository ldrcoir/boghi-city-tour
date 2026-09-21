#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""بوقی قرمز-زرد: بازگرداندن رنگ قرمزِ کانسپت تأییدشده به اسپرایت بوقی + آیکون
   + پاک‌سازی لکه‌های نویز پراید قرمز. چشم‌ها، سایه‌ها و جزئیات حفظ می‌شوند."""
from PIL import Image, ImageFilter
import colorsys
import sys

SPRITES = "/home/z/my-project/game/assets/sprites"


def hsv(px):
    return colorsys.rgb_to_hsv(px[0] / 255, px[1] / 255, px[2] / 255)


def recolor_boghi(path, eye_rect, sample_only=False):
    """eye_rect = (x0,y0,x1,y1) نسبت به ابعاد تصویر — رنگ‌های سرمه‌ای چشم داخل این قاب حفظ می‌شود"""
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if sample_only:
        c_eye, c_body = {}, {}
        for x in range(w):
            for y in range(h):
                r, g, b, a = img.getpixel((x, y))
                if a < 10:
                    continue
                hh, ss, vv = hsv((r, g, b, a))
                if ss < 0.3 or vv < 0.15:
                    continue
                ex, ey = x / w, y / h
                in_eye = eye_rect[0] <= ex <= eye_rect[2] and eye_rect[1] <= ey <= eye_rect[3]
                bucket = c_eye if in_eye else c_body
                bucket[round(hh, 1)] = bucket.get(round(hh, 1), 0) + 1
        print(f"  {path.split('/')[-1]}  size={w}x{h}")
        print("    EYE-RECT hues:", sorted(c_eye.items(), key=lambda kv: -kv[1])[:6])
        print("    BODY hues:", sorted(c_body.items(), key=lambda kv: -kv[1])[:6])
        return
    px = img.load()
    ex0, ey0, ex1, ey1 = eye_rect
    changed = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, ss, vv = hsv((r, g, b, a))
            nx, ny = x / w, y / h
            in_eye = ex0 <= nx <= ex1 and ey0 <= ny <= ey1
            # حفظ چشم‌های سرمه‌ای داخل قاب
            if in_eye and 0.54 <= hh <= 0.78:
                continue
            # بازه فیروزه‌ای/سبز-آبی بدنه (شامل سایه‌های تیره h~0.65-0.68)
            if 0.38 <= hh <= 0.70 and ss > 0.05 and vv > 0.08:
                nh = 0.995 + (hh - 0.50) * 0.05
                ns = min(1.0, ss * 1.22)
                nv = min(1.0, vv * 1.04)
                nr, ng, nb = colorsys.hsv_to_rgb(nh % 1.0, ns, nv)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
                changed += 1
    img.save(path)
    print(f"  recolored {changed}/{w*h} px -> {path.split('/')[-1]}")


def despeckle(path):
    """حذف نقطه‌های نویز تیره داخل بدنهٔ قرمز: فقط پیکسل تیره‌ای که میانهٔ
       همسایگی ۷×۷ آن روشنِ قرمز است، با میانه جایگزین می‌شود."""
    img = Image.open(path).convert("RGBA")
    med = img.filter(ImageFilter.MedianFilter(size=7))
    p1, p2 = img.load(), med.load()
    w, h = img.size
    fixed = 0
    for y in range(2, h - 2):
        for x in range(2, w - 2):
            r, g, b, a = p1[x, y]
            if a == 0:
                continue
            hh, ss, vv = hsv((r, g, b, a))
            mh, ms, mv = hsv(p2[x, y])
            red = (mh % 1.0) <= 0.14 or (mh % 1.0) >= 0.90
            if vv < 0.32 and mv > 0.45 and ms > 0.35 and red:
                p1[x, y] = p2[x, y]
                fixed += 1
    img.save(path)
    print(f"  despeckled {fixed} px -> {path.split('/')[-1]}")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "run"
    print("[1] boghi_side.png")
    recolor_boghi(f"{SPRITES}/boghi_side.png", (0.28, 0.14, 0.72, 0.44), sample_only=(mode == "sample"))
    if mode != "sample":
        print("[2] icon.png")
        recolor_boghi("/home/z/my-project/game/icon.png", (0.26, 0.16, 0.74, 0.48))
        print("[3] pride_side.png despeckle")
        despeckle(f"{SPRITES}/pride_side.png")
