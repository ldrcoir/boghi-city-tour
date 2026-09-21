#!/usr/bin/env python3
# لوگوی رسمی «بوقی: تور شهرها» — بوقی + تیتر لاله‌زار طلایی + برند استودیو ایماروید
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

ROOT = "/home/z/my-project/game"
SPR = os.path.join(ROOT, "assets/sprites")
OUT_MENU = os.path.join(SPR, "logo.png")
OUT_WEB = "/home/z/my-project/public/apk/logo.png"

GOLD = (245, 194, 64, 255)
DARK = (26, 14, 5, 255)
CREAM = (255, 246, 224, 255)
RED = (200, 38, 30, 255)

LALEZAR = os.path.join(ROOT, "assets/fonts/Lalezar-Regular.ttf")
VAZIR = os.path.join(ROOT, "assets/fonts/Vazirmatn-Bold.ttf")

def text_layer(size, text, fill, stroke, stroke_w, anchor="ra", pad=0, font_file=None):
    f = ImageFont.truetype(font_file or LALEZAR, size)
    W = int(size * len(text)) + 600
    Hc = int(size * 3.4)  # فونت نمایشی فارسی اوجِ بلند دارد — بوم بلند، لنگر میانی
    img = Image.new("RGBA", (W, Hc), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.text((W // 2, Hc // 2), text, font=f, fill=fill,
           stroke_width=stroke_w, stroke_fill=stroke,
           anchor="mm", direction="rtl", language="fa")
    bbox = img.getbbox()
    return img.crop(bbox)

# --- بوقی ---
car = Image.open(os.path.join(SPR, "boghi_side.png")).convert("RGBA")
target_h = 430
sc = target_h / car.height
car = car.resize((int(car.width * sc), target_h), Image.LANCZOS)

# --- تیتر ---
title = text_layer(180, "بوقی: تور شهرها", GOLD, DARK, 12)
studio = text_layer(54, "از استودیو ایماروید", CREAM, DARK, 6,
                    font_file=VAZIR)

W, H = 1560, 560
logo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(logo)

# بوقی سمت راست (شروع RTL)
cx = W - 40 - car.width
logo.alpha_composite(car, (cx, H - car.height - 26))

# تیتر بالای سمت چپِ بوقی — مختصات هرگز منفی نشود
tx = cx - 60
title = title if title.width <= tx - 20 else title.resize(
    (int(title.width * (tx - 20) / title.width), int(title.height * (tx - 20) / title.width)),
    Image.LANCZOS)
logo.alpha_composite(title, (tx - title.width, 34))

# نوار قرمز زیر تیتر
bar_y = 34 + title.height + 22
d.rounded_rectangle([tx - 320, bar_y, tx - 40, bar_y + 13], 6, fill=RED)

# برند استودیو زیر نوار
sx = tx - 40 - studio.width
logo.alpha_composite(studio, (max(10, sx), bar_y + 34))

bbox = logo.getbbox()
logo = logo.crop(bbox)
logo.save(OUT_MENU)
os.makedirs(os.path.dirname(OUT_WEB), exist_ok=True)
logo.save(OUT_WEB)
print("menu logo:", logo.size, "->", OUT_MENU)
print("web  logo:", logo.size, "->", OUT_WEB)

# نسخه وب با پس‌زمینه تیره گرد — برای صفحه دانلود و گیت‌هاب
wb = logo.copy()
sc = min(1100 / wb.width, 420 / wb.height)
wb = wb.resize((int(wb.width * sc), int(wb.height * sc)), Image.LANCZOS)
card = Image.new("RGBA", (wb.width + 120, wb.height + 110), (0, 0, 0, 0))
cd = ImageDraw.Draw(card)
cd.rounded_rectangle([0, 0, card.width - 1, card.height - 1], 44,
                     fill=(16, 15, 18, 235), outline=(245, 194, 64, 255), width=5)
card.alpha_composite(wb, (60, 48))
card.convert("RGB").save("/home/z/my-project/public/apk/logo_card.png")
print("card logo:", card.size)
