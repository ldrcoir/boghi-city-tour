#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen15_fx — بافت‌های نور/ذره، پس‌زمینه سینمایی منو، لوگو، پس‌زمینه گاراژ."""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

OUT = "/home/z/my-project/game/assets/sprites"
R = random.Random(1515)

def radial(size, stops, squish=1.0):
    """گرادیان شعاعی نرم — stops: [(t, (r,g,b,a)), ...]"""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = (w - 1) / 2, (h - 1) / 2
    dist = np.sqrt(((xx - cx) / (w / 2)) ** 2 + (((yy - cy) / (h / 2)) * squish) ** 2)
    ts = np.array([s[0] for s in stops])
    arr = np.zeros((h, w, 4), dtype=np.float32)
    for c in range(4):
        vals = np.array([s[1][c] for s in stops], dtype=np.float32)
        arr[:, :, c] = np.interp(dist, ts, vals)
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")

def save(img, name):
    img.save(os.path.join(OUT, name))
    print("fx:", name, img.size)

# ── نور نرم (چراغ خیابان/هاله) ──
save(radial((256, 256), [(0, (255, 255, 255, 255)), (0.35, (255, 250, 235, 160)),
                         (0.7, (255, 245, 220, 45)), (1, (255, 240, 210, 0))]), "light_soft.png")
# ── هاله‌ی طلایی تیتر ──
save(radial((512, 256), [(0, (255, 210, 90, 110)), (0.5, (255, 180, 60, 40)), (1, (255, 160, 40, 0))],
            squish=2.0), "title_glow.png")
# ── دود دریفت ──
sm = radial((128, 128), [(0, (235, 235, 240, 200)), (0.5, (210, 210, 220, 110)), (1, (200, 200, 215, 0))])
n = (np.asarray(sm, dtype=np.float32))
noise = np.random.RandomState(7).rand(128, 128, 1)
n[:, :, 3] *= (0.72 + 0.28 * noise[:, :, 0])[:, :]
sm = Image.fromarray(np.clip(n, 0, 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(3))
save(sm, "smoke.png")
# ── شعله‌ی نیترو (آبی-بنفش) ──
fl = Image.new("RGBA", (96, 160), (0, 0, 0, 0))
fd = ImageDraw.Draw(fl)
for i in range(26):
    t = i / 26
    y = 150 - t * 140
    wdt = 34 * (1 - t) * (0.75 + 0.25 * math.sin(t * 9))
    col = (90 + int(160 * (1 - t)), 150 + int(90 * (1 - t)), 255, int(150 * (1 - t * 0.7)))
    fd.ellipse([48 - wdt / 2, y - 14, 48 + wdt / 2, y + 14], fill=col)
fl = fl.filter(ImageFilter.GaussianBlur(4))
save(fl, "flame.png")
# ── مخروط نور چراغ ماشین — نرم واقعی، نه ذوزنقه‌ی زشت ──
cone = Image.new("RGBA", (512, 320), (0, 0, 0, 0))
cd = ImageDraw.Draw(cone)
for i in range(40):
    t = i / 40
    x0 = 40 + t * 440
    spread = 8 + t * 128
    a = int(120 * (1 - t) ** 1.6)
    cd.ellipse([x0 - 30, 160 - spread, x0 + 30, 160 + spread], fill=(255, 236, 190, a))
core = Image.new("RGBA", (512, 320), (0, 0, 0, 0))
ImageDraw.Draw(core).ellipse([10, 130, 110, 190], fill=(255, 246, 215, 170))
cone = Image.alpha_composite(cone, core).filter(ImageFilter.GaussianBlur(22))
save(cone, "headlight_cone.png")
# ── سکه — طلایی گرم با هاله ──
coin = radial((64, 64), [(0, (255, 244, 180, 255)), (0.42, (255, 208, 64, 255)),
                         (0.62, (200, 140, 30, 255)), (0.8, (255, 220, 100, 120)), (1, (255, 210, 90, 0))])
cd2 = ImageDraw.Draw(coin)
cd2.ellipse([18, 18, 46, 46], outline=(120, 78, 10, 255), width=3)
try:
    fnt = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    cd2.text((32, 31), "★", font=fnt, fill=(255, 246, 200, 255), anchor="mm")
except Exception:
    pass
save(coin, "coin.png")

# ═══════════════ پس‌زمینه‌ی منو — شب تهران سینمایی ═══════════════
def menu_bg():
    W, H = 1280, 720
    img = Image.new("RGB", (W, H))
    # آسمان — آبی-بنفش عمیق ولی قابل دیدن
    arr = np.zeros((H, W, 3), dtype=np.float32)
    top, mid, hor = (16, 22, 48), (34, 44, 88), (72, 66, 104)
    for y in range(H):
        t = y / H
        if t < 0.45:
            f = t / 0.45
            c = [top[i] + (mid[i] - top[i]) * f for i in range(3)]
        else:
            f = (t - 0.45) / 0.55
            c = [mid[i] + (hor[i] - mid[i]) * f for i in range(3)]
        arr[y, :] = c
    img = Image.fromarray(arr.astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    # ستاره‌ها
    for _ in range(280):
        x, y = R.randint(0, W), R.randint(0, int(H * 0.5))
        a = R.randint(90, 210)
        d.point((x, y), fill=(a, a, min(255, a + 30)))
    # درخشش ماه — گوشه‌ی بالا-راست
    moon = radial((500, 500), [(0, (200, 220, 255, 60)), (0.3, (160, 190, 240, 22)), (1, (0, 0, 0, 0))])
    ml = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ml.paste(moon, (950, -120), moon)
    img = Image.alpha_composite(img, ml)
    m2 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(m2).ellipse([1052, 62, 1074, 84], fill=(240, 246, 255, 255))
    m2 = m2.filter(ImageFilter.GaussianBlur(1.2))
    img = Image.alpha_composite(img, m2)

    # درخشش گرم افق پشت شهر — قبل از خط آسمان‌خراش‌ها
    cityglow = radial((1700, 620), [(0, (255, 150, 70, 90)), (0.5, (220, 110, 90, 40)), (1, (0, 0, 0, 0))],
                      squish=2.6)
    cg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cg.paste(cityglow, (W // 2 - 850, int(H * 0.42) - 200), cityglow)
    img = Image.alpha_composite(img, cg)

    NEONS = [(80, 225, 255), (255, 90, 150), (255, 180, 70), (165, 130, 255), (120, 255, 190)]

    def skyline(ybase, hmin, hmax, col, win_p, blur, neon_p, win_col=(255, 216, 150)):
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(lay)
        neon_lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        nd = ImageDraw.Draw(neon_lay)
        x = -20
        while x < W + 20:
            bw = R.randint(46, 130)
            bh = R.randint(hmin, hmax)
            x0, y0 = x, ybase - bh
            ld.rectangle([x0, y0, x + bw, ybase], fill=col + (255,))
            for wy in range(y0 + 8, ybase - 6, 12):
                for wx in range(x0 + 5, x + bw - 6, 10):
                    r = R.random()
                    if r < win_p:
                        ld.rectangle([wx, wy, wx + 4, wy + 5], fill=win_col + (235,))
                    elif r < win_p + 0.05:
                        ld.rectangle([wx, wy, wx + 4, wy + 5], fill=(150, 195, 255, 220))
            if R.random() < neon_p:
                nx = x0 + R.randint(8, max(9, bw - 26))
                nc = R.choice(NEONS)
                ny0 = y0 + R.randint(12, 40)
                nh = int(bh * R.uniform(0.35, 0.65))
                nd.rectangle([nx, ny0, nx + R.randint(6, 9), ny0 + nh], fill=nc + (255,))
                # تابلوی باریک بام
                if R.random() < 0.4:
                    sw = int((bw - 24) * R.uniform(0.35, 0.7))
                    nd.rectangle([x0 + 12, y0 + 9, x0 + 12 + sw, y0 + 15], fill=nc + (230,))
            if R.random() < 0.2:
                ax = x0 + bw // 2
                ld.line([(ax, y0), (ax, y0 - R.randint(16, 40))], fill=col + (255,), width=2)
                ld.ellipse([ax - 3, y0 - 44, ax + 3, y0 - 38], fill=(255, 70, 55, 255))
            x += bw + R.randint(2, 14)
        lay = Image.alpha_composite(lay, neon_lay.filter(ImageFilter.GaussianBlur(6)))
        lay = Image.alpha_composite(lay, neon_lay)
        if blur:
            lay = lay.filter(ImageFilter.GaussianBlur(blur))
        return lay

    img = Image.alpha_composite(img, skyline(int(H * 0.50), 70, 160, (18, 24, 48), 0.10, 2.0, 0.10))
    img = Image.alpha_composite(img, skyline(int(H * 0.58), 90, 210, (14, 18, 40), 0.15, 1.0, 0.14))
    img = Image.alpha_composite(img, skyline(int(H * 0.70), 110, 270, (10, 13, 30), 0.20, 0.0, 0.20))

    # ── خیابان خیس از پایین — گرادیان روشن نزدیک افق
    road_top = int(H * 0.70)
    rarr = np.zeros((H, W, 4), dtype=np.float32)
    c_far, c_near = np.array((56, 58, 82), dtype=np.float32), np.array((15, 16, 26), dtype=np.float32)
    for y in range(road_top, H):
        f = (y - road_top) / max(1, H - road_top)
        c = c_far + (c_near - c_far) * f
        rarr[y, :, 0] = c[0]; rarr[y, :, 1] = c[1]; rarr[y, :, 2] = c[2]; rarr[y, :, 3] = 255
    road = Image.fromarray(rarr.astype(np.uint8), "RGBA")
    # جلای خیس مرکز — بازتاب نور شهر
    sheen = radial((900, 500), [(0, (180, 170, 210, 42)), (1, (0, 0, 0, 0))], squish=3.2)
    sheen_l = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sheen_l.paste(sheen, (W // 2 - 450, road_top - 90), sheen)
    road = Image.alpha_composite(road, sheen_l)
    img = Image.alpha_composite(img, road)
    # انعکاس‌های نئون — درخشان و کشیده
    ref = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rr = ImageDraw.Draw(ref)
    for _ in range(40):
        x = R.randint(0, W)
        c = R.choice(NEONS + [(255, 224, 160)])
        ln = R.randint(90, 300)
        wdt = R.randint(3, 10)
        a = R.randint(38, 88)
        y0 = road_top + R.randint(0, 50)
        rr.rectangle([x, y0, x + wdt, min(H, y0 + ln)], fill=c + (a,))
    ref = ref.filter(ImageFilter.GaussianBlur(6))
    img = Image.alpha_composite(img, ref)
    # هاله‌ی نور شهر روی آسفالت
    for _ in range(10):
        x, y = R.randint(0, W), R.randint(road_top + 30, H - 20)
        glow = radial((260, 90), [(0, (150, 130, 190, 34)), (1, (0, 0, 0, 0))], squish=3.0)
        img.paste(glow, (x - 130, y - 45), glow)
    # خط‌های جاده — پیوسته تا نقطه گریز؛ لبه سفید، وسط دوتایی زرد، لاین‌چین
    rd = ImageDraw.Draw(img)
    vp = (W * 0.52, road_top - 6)
    def lane_x(y, k):
        f = (y - road_top) / (H - road_top)
        return vp[0] + k * 160 * (0.05 + 0.95 * f)
    for k in (-3, 3):
        pts = [(lane_x(y, k), y) for y in range(road_top + 4, H + 1, 8)]
        rd.line(pts, fill=(210, 214, 228, 80), width=4)
    for k in (-1, 1):
        y = H + 20
        while y > road_top + 6:
            y2 = int(y - (y - road_top) * 0.16) - 2
            if y2 < road_top + 4:
                break
            rd.line([(lane_x(y, k), y), (lane_x(y2, k), y2)], fill=(215, 218, 230, 72), width=4)
            y = int(y - (y - road_top) * 0.30)
    for k in (-0.012, 0.012):
        pts = [(vp[0] + k * W * (0.05 + 0.95 * (y - road_top) / (H - road_top)), y)
               for y in range(road_top + 4, H + 1, 10)]
        rd.line(pts, fill=(226, 186, 70, 120), width=3)
    # بوکه‌های چراغ
    bok = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bok)
    for _ in range(22):
        x = R.randint(30, W - 30)
        y = R.randint(int(H * 0.52), int(H * 0.78))
        r = R.randint(8, 22)
        c = R.choice(NEONS + [(255, 240, 200)])
        bd.ellipse([x - r, y - r // 2, x + r, y + r // 2], fill=c + (52,))
    bok = bok.filter(ImageFilter.GaussianBlur(7))
    img = Image.alpha_composite(img, bok)
    # وینیت ملایم — مرکز دست‌نخورده
    vig = radial((W, H), [(0, (0, 0, 0, 0)), (0.68, (0, 0, 0, 0)), (1, (2, 3, 10, 150))])
    img = Image.alpha_composite(img, vig)
    # دانه‌ی فیلم
    arr = np.asarray(img, dtype=np.int16)
    g = np.random.RandomState(5).randint(-5, 5, (H, W, 1), dtype=np.int16)
    arr = np.clip(arr + g, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr, "RGBA")
    img.convert("RGB").save(os.path.join(OUT, "menu_bg.png"))
    print("fx: menu_bg.png")

# ═══════════════ لوگوی بوت — «بوقی» با فونت لاله‌زار ═══════════════
def logo():
    W, H = 560, 260
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    try:
        fnt = ImageFont.truetype("/home/z/my-project/game/assets/fonts/Lalezar-Regular.ttf", 150)
        gd = ImageDraw.Draw(glow)
        gd.text((W // 2, H // 2 - 6), "بوقی", font=fnt, fill=(255, 190, 60, 210), anchor="mm",
                direction="rtl", features=["kern"])
        glow = glow.filter(ImageFilter.GaussianBlur(16))
        img = Image.alpha_composite(img, glow)
        d = ImageDraw.Draw(img)
        for off, col in [(6, (60, 22, 4, 255)), (0, (255, 214, 92, 255))]:
            d.text((W // 2 + off, H // 2 - 6 + off), "بوقی", font=fnt, fill=col, anchor="mm",
                   direction="rtl", features=["kern"])
        d.text((W // 2, H - 34), "تور شهرها", font=ImageFont.truetype(
            "/home/z/my-project/game/assets/fonts/Lalezar-Regular.ttf", 44),
            fill=(235, 228, 210, 255), anchor="mm", direction="rtl")
        img.save(os.path.join(OUT, "logo.png"))
        print("fx: logo.png")
    except Exception as e:
        print("logo skipped:", e)

# ═══════════════ پس‌زمینه‌ی گاراژ ═══════════════
def garage_bg():
    W, H = 1280, 720
    img = Image.new("RGB", (W, H), (16, 17, 22))
    d = ImageDraw.Draw(img)
    # دیوار پنلی
    for x in range(0, W, 84):
        d.rectangle([x, 0, x + 80, int(H * 0.62)], fill=(22, 24, 31) if (x // 84) % 2 == 0 else (20, 22, 28))
        d.line([(x, 0), (x, int(H * 0.62))], fill=(12, 13, 18), width=4)
    # کف
    d.rectangle([0, int(H * 0.62), W, H], fill=(24, 26, 32))
    for y in range(int(H * 0.62), H, 26):
        d.line([(0, y), (W, y)], fill=(19, 21, 26), width=2)
    # نوار نئون افقی
    neon = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    nd = ImageDraw.Draw(neon)
    nd.rectangle([60, 88, W - 60, 100], fill=(255, 150, 40, 220))
    nd.rectangle([60, 130, W - 60, 134], fill=(90, 200, 255, 160))
    neon = neon.filter(ImageFilter.GaussianBlur(6))
    img = Image.alpha_composite(img.convert("RGBA"), neon).convert("RGB")
    d = ImageDraw.Draw(img)
    # قفسه ابزار سیلوئت
    for sx in (140, 1080):
        d.rectangle([sx, 300, sx + 160, 440], fill=(15, 16, 21))
        for k in range(4):
            d.rectangle([sx + 12, 312 + k * 32, sx + 148, 336 + k * 32], fill=(26, 28, 36))
    # حلقه‌های لاستیک انبار
    for k in range(3):
        d.ellipse([520 + k * 8, 470 - k * 26, 700 - k * 8, 590 - k * 26], outline=(34, 36, 44), width=16)
    # وینیت
    vig = radial((W, H), [(0, (0, 0, 0, 0)), (0.6, (0, 0, 0, 0)), (1, (0, 0, 0, 190))]).convert("RGB")
    img = ImageChops.multiply(img, vig)
    img.save(os.path.join(OUT, "garage_bg.png"))
    os.system(f"cd {OUT} && python3 -c \"from PIL import Image; Image.open('garage_bg.png').save('garage_bg.webp','WEBP',quality=88)\"")
    print("fx: garage_bg")

menu_bg()
logo()
garage_bg()
