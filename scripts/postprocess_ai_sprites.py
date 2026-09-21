#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پس‌پردازش خروجی AI: کی ماژنتا → آلفا → هم‌اندازه‌سازی → جایگزینی اسپرایت"""
from PIL import Image, ImageFilter

S = "/home/z/my-project/scripts"
A = "/home/z/my-project/game/assets/sprites"

def key_magenta(img):
    """ماژنتا → شفاف + پاک‌سازی هاله و سایه ماژنتایی + حذف نقطه‌های ریز"""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mn = min(r, b)
            # خانواده ماژنتا: سبز خیلی کم نسبت به قرمز/آبی — در همه روشنایی‌ها
            if r > 80 and mn > 55 and g < 0.45 * mn:
                px[x, y] = (r, g, b, 0)
            elif r > 40 and mn > 35 and g < 0.40 * mn:
                px[x, y] = (r, g, b, 0)
    # حذف نقطه‌های آلفای پراکنده + نرم‌کردن لبه
    r_, g_, b_, a_ = img.split()
    a_ = a_.filter(ImageFilter.MedianFilter(3))
    a_ = a_.point(lambda v: 0 if v < 45 else v)
    a_ = a_.filter(ImageFilter.GaussianBlur(0.7))
    img = Image.merge("RGBA", (r_, g_, b_, a_))
    return img

def bbox_of(img, thr=80):
    am = img.getchannel("A").point(lambda v: 255 if v > thr else 0)
    am = am.filter(ImageFilter.MedianFilter(5))
    return am.getbbox()

def paste_anchored(canvas, cut, orig_bbox):
    """برش جدید را با لنگر پایین-وسط در بباکس اصلی می‌گذارد"""
    ox0, oy0, ox1, oy1 = orig_bbox
    oh = oy1 - oy0
    nh = cut.height
    k = oh / nh
    nw = max(1, int(cut.width * k))
    cut = cut.resize((nw, oh), Image.LANCZOS)
    cx = (ox0 + ox1) // 2
    px0 = cx - nw // 2
    py0 = oy1 - oh
    canvas.alpha_composite(cut, (px0, py0))

# ---------- استاد فنر ----------
orig = Image.open(f"{S}/ustad_backup_v1.png").convert("RGBA")
ob = bbox_of(orig)
new = key_magenta(Image.open(f"{S}/ustad_edit_raw.png"))
nb = bbox_of(new)
cut = new.crop(nb)
canvas = Image.new("RGBA", orig.size, (0, 0, 0, 0))
paste_anchored(canvas, cut, ob)
canvas.save(f"{A}/ustad.png")
print("ustad: orig_bbox", ob, "new_bbox", nb, "-> saved")

# ---------- ماشین‌ها ----------
targets = [
    (f"{S}/dena_race_raw.png", f"{A}/dena_race_side.png", 259),
    (f"{S}/pejo_race_raw.png", f"{A}/pejo_race_side.png", 264),
]
for src, out, th in targets:
    im = key_magenta(Image.open(src))
    bb = bbox_of(im)
    im = im.crop(bb)
    k = th / im.height
    tw = max(1, int(im.width * k))
    im = im.resize((tw, th), Image.LANCZOS)
    im.save(out)
    print(out.split("/")[-1], "size:", im.size)

# ---------- برگه QC ۲ ----------
qc = Image.new("RGB", (1080, 640), (222, 222, 218))
u = Image.open(f"{A}/ustad.png")
qc.paste(u, (30, 120), u)
d = Image.open(f"{A}/dena_race_side.png")
qc.paste(d, (300, 40), d)
p = Image.open(f"{A}/pejo_race_side.png")
qc.paste(p, (300, 340), p)
qc.save(f"{S}/qc_sheet2.png")
print("saved qc_sheet2.png")
