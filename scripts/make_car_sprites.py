#!/usr/bin/env python3
# پردازش اسپرایت‌های تولیدشده: حذف پس‌زمینه (flood-fill از لبه‌ها، متحمل گرادیان
# و سایه‌ی نرم)، رفع هاله‌ی صورتی، برش محتوا، یکسان‌سازی قاب، خروجی به بازی
import os, sys, glob
from collections import deque
from PIL import Image, ImageFilter

SRC = "/home/z/my-project/scripts/car_gen"
DST = "/home/z/my-project/game/assets/sprites"
DEBUG = "/home/z/my-project/scripts/car_cut"

os.makedirs(DEBUG, exist_ok=True)

def flood_bg(px, w, h, seed_tol=42, grad_tol=13, shadow_floor=70):
    """حذف پس‌زمینه با BFS از لبه‌ها.
    seed_tol: فاصله‌ی مجاز از رنگ مرجع گوشه‌ها
    grad_tol: حداکثر پرش بین پیکسل همسایه (گرادیان بک‌گراند را می‌بلعد)
    shadow_floor: تیرگی مطلق — سایه‌های تخت تیره‌تر از این مقدار حذف نمی‌شوند
    (ماشین‌های تیره مثل شاهین سالم می‌مانند)
    """
    corners = [px[0, 0][:3], px[w-1, 0][:3], px[0, h-1][:3], px[w-1, h-1][:3]]
    ref = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    bg = bytearray(w * h)  # 1 = background
    q = deque()

    def near_ref(c):
        return sum((c[i] - ref[i]) ** 2 for i in range(3)) ** 0.5 <= seed_tol

    for x in range(w):
        for y in (0, h - 1):
            if not bg[y*w+x] and near_ref(px[x, y][:3]):
                bg[y*w+x] = 1; q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not bg[y*w+x] and near_ref(px[x, y][:3]):
                bg[y*w+x] = 1; q.append((x, y))

    while q:
        x, y = q.popleft()
        c = px[x, y][:3]
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h and not bg[ny*w+nx]:
                n = px[nx, ny][:3]
                if near_ref(n):
                    bg[ny*w+nx] = 1; q.append((nx, ny))
                    continue
                # ادامه‌ی گرادیانِ بک‌گراند (بدون پرش تیز)
                jump = sum((n[i]-c[i])**2 for i in range(3)) ** 0.5
                lum = 0.299*n[0] + 0.587*n[1] + 0.114*n[2]
                if jump <= grad_tol and lum >= shadow_floor:
                    bg[ny*w+nx] = 1; q.append((nx, ny))
    return bg

def process(path, out_path, target_w=640):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    bg = flood_bg(px, w, h)

    rgba = im.convert("RGBA")
    alpha = rgba.split()[3].load()
    for y in range(h):
        row = y * w
        for x in range(w):
            if bg[row + x]:
                alpha[x, y] = 0

    # هاله‌ی صورتی روی لبه‌ها: پیکسل‌های نیمه‌شفافِ صورتی‌زا بی‌رنگ می‌شوند
    p = rgba.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = p[x, y]
            if 0 < a < 255 and r > 120 and b > 90 and g < r * 0.75 and g < b * 0.85:
                p[x, y] = (200, 200, 200, a)

    # برش روی محتوا
    bbox = rgba.getbbox()
    if bbox:
        rgba = rgba.crop(bbox)
    cw, ch = rgba.size

    # قاب یکسان: عرض هدف، حاشیه‌ی شفاف استاندارد تا مقیاس ماشین‌ها هم‌خوان شود
    scale = target_w / cw
    nh = max(1, int(ch * scale))
    rgba = rgba.resize((target_w, nh), Image.LANCZOS)

    # لبه‌ی نرم: کمی فرسایش + بلور آلفا برای ضدجگ‌درد
    a = rgba.split()[3].filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    rgba.putalpha(a)

    rgba.save(out_path, optimize=True)
    return rgba.size

def main():
    only = sys.argv[1] if len(sys.argv) > 1 else "all"
    files = sorted(glob.glob(os.path.join(SRC, "*.png")))
    for f in files:
        cid = os.path.splitext(os.path.basename(f))[0]
        if only != "all" and only != cid:
            continue
        try:
            out = os.path.join(DST, f"{cid}_side.png")
            size = process(f, out)
            rgba = Image.open(out)
            # گزارش پوشش آلفا برای کنترل سلامت
            a = rgba.split()[3]
            hist = a.histogram()
            opaque = sum(hist[200:])
            total = rgba.size[0] * rgba.size[1]
            print(f"{cid}: {rgba.size} opaque={opaque*100//total}% -> {out}")
        except Exception as e:
            print(f"{cid}: FAILED {e}")

if __name__ == "__main__":
    main()
