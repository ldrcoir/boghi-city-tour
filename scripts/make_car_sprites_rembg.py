#!/usr/bin/env python3
"""برش حرفه‌ای اسپرایت‌ها با rembg (U2Net) + یکسان‌سازی قاب و خروجی به بازی.
اجرا با /usr/bin/python3 (پایتون سیستم — rembg در venv نصب نیست).
هر ۱۶ ماشین از scripts/car_gen به game/assets/sprites/{id}_side.png
"""
import os, sys, glob
from PIL import Image, ImageFilter
from rembg import remove, new_session

SRC = "/home/z/my-project/scripts/car_gen"
DST = "/home/z/my-project/game/assets/sprites"
TARGET_W = 640

def main():
    only = sys.argv[1] if len(sys.argv) > 1 else "all"
    session = new_session("u2net")
    files = sorted(glob.glob(os.path.join(SRC, "*.png")))
    for f in files:
        cid = os.path.splitext(os.path.basename(f))[0]
        if only != "all" and only != cid:
            continue
        out = os.path.join(DST, f"{cid}_side.png")
        try:
            im = Image.open(f).convert("RGBA")
            cut = remove(
                im,
                session=session,
                alpha_matting=True,
                alpha_matting_foreground_threshold=240,
                alpha_matting_background_threshold=15,
                alpha_matting_erode_size=8,
            )
            # برش روی محتوا
            bbox = cut.getbbox()
            if bbox:
                cut = cut.crop(bbox)
            cw, ch = cut.size
            scale = TARGET_W / cw
            nh = max(1, int(ch * scale))
            cut = cut.resize((TARGET_W, nh), Image.LANCZOS)
            # لبه‌ی نرم
            a = cut.split()[3].filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
            cut.putalpha(a)
            cut.save(out, optimize=True)
            total = cut.size[0] * cut.size[1]
            hist = cut.split()[3].histogram()
            opaque = sum(hist[200:])
            print(f"{cid}: {cut.size} opaque={opaque*100//total}% bytes={os.path.getsize(out)}")
        except Exception as e:
            print(f"{cid}: FAILED {e}")

if __name__ == "__main__":
    main()
