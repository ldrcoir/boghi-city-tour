#!/usr/bin/env python3
# پس‌زمینه منو = رفرنس track_tehran کاربر: برش cover به 1280x720،
# تیره‌سازی ملایم برای کنتراست UI، خروجی WebP فشرده
from PIL import Image, ImageEnhance

SRC = "/home/z/my-project/upload/track_tehran.png"
DST = "/home/z/my-project/game/assets/sprites/menu_bg.webp"

im = Image.open(SRC).convert("RGB")
sw, sh = im.size
tw, th = 1280, 720
scale = max(tw / sw, th / sh)
nw, nh = int(sw * scale + 0.5), int(sh * scale + 0.5)
im = im.resize((nw, nh), Image.LANCZOS)
left = (nw - tw) // 2
top = int((nh - th) * 0.42)  # کمی بالاتر از مرکز تا برج آزادی و خورشید کامل بمانند
im = im.crop((left, top, left + tw, top + th))

# تیره‌سازی ملایم: پنل شیشه‌ای و متن‌ها خواناتر می‌شوند
im = ImageEnhance.Brightness(im).enhance(0.90)
im = ImageEnhance.Color(im).enhance(1.04)

im.save(DST, "WEBP", quality=86, method=6)
print("saved", DST, im.size)

import os
print("bytes:", os.path.getsize(DST))
