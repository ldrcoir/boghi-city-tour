#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen15_map — بیک شهر شبانه‌ی بوقی v0.15
کل زمینِ استاتیک (آسفالت/پیاده‌رو/خط‌کشی/ساختمان/نئون/درخت/چراغ) در ۴ تایل
کیفیت‌بالا پیش‌رندر می‌شود + city_layout.json (برخوردها/مسیر) تحویل بازی.
پیست: همان ۸ گوشه با فیله‌ی قوس‌دار نرم (r=170)."""
import os, json, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

OUT = "/home/z/my-project/game/assets/sprites"
DATA = "/home/z/my-project/game/data"
SS = 2                 # سوپرسمپل رندر
DS = 1.0                # مقیاس نهایی تایل (px/world) — ۱:۱ برای شارپ بودن
RECT = (240.0, 240.0, 6160.0, 5160.0)   # محدوده‌ی دنیا (world units)
ROAD_HALF = 130.0
WALK_HALF = 196.0
R_FIL = 170.0

WPS = [(1215, 1215), (4320, 1215), (5130, 2025), (5130, 3645),
       (4320, 4455), (2025, 4455), (1215, 3645), (1215, 2025)]

NEON_COLS = [(80, 225, 255), (255, 150, 70), (255, 90, 150), (140, 255, 170), (255, 220, 110), (170, 140, 255)]
ROOF_COLS = [(34, 36, 48), (40, 38, 46), (30, 36, 44), (46, 38, 38), (36, 42, 40), (44, 44, 54)]

def unit(v):
    l = math.hypot(v[0], v[1]) or 1.0
    return (v[0] / l, v[1] / l)

def build_centerline():
    """۸ گوشه + فیله — خروجی: نقاط چگال بسته + ایندکس‌های قوس."""
    n = len(WPS)
    V = [tuple(map(float, p)) for p in WPS]
    chain = []
    arc_idx = set()
    for i in range(n):
        A, B, C = V[(i - 1) % n], V[i], V[(i + 1) % n]
        d1 = unit((B[0] - A[0], B[1] - A[1]))
        d2 = unit((C[0] - B[0], C[1] - B[1]))
        dot = max(-1.0, min(1.0, d1[0] * d2[0] + d1[1] * d2[1]))
        th = math.acos(dot)
        if th < 0.05:
            chain.append(B)
            continue
        T = min(R_FIL * math.tan(th / 2), 0.42 * min(math.hypot(B[0] - A[0], B[1] - A[1]),
                                                     math.hypot(C[0] - B[0], C[1] - B[1])))
        S = (B[0] - d1[0] * T, B[1] - d1[1] * T)
        E = (B[0] + d2[0] * T, B[1] + d2[1] * T)
        side = 1.0 if (d1[0] * d2[1] - d1[1] * d2[0]) > 0 else -1.0
        n1 = (-d1[1] * side, d1[0] * side)
        O = (S[0] + n1[0] * R_FIL, S[1] + n1[1] * R_FIL)
        a0 = math.atan2(S[1] - O[1], S[0] - O[0])
        a1 = math.atan2(E[1] - O[1], E[0] - O[0])
        # جهت پیمایش قوس مطابق side
        if side > 0:
            while a1 < a0:
                a1 += 2 * math.pi
        else:
            while a1 > a0:
                a1 -= 2 * math.pi
        steps = max(6, int(abs(a1 - a0) * R_FIL / 9))
        base = len(chain)
        for k in range(steps + 1):
            a = a0 + (a1 - a0) * k / steps
            chain.append((O[0] + math.cos(a) * R_FIL, O[1] + math.sin(a) * R_FIL))
            arc_idx.add(base + k)
        # خط صاف تا شروع فیله‌ی بعدی
        nxt = V[(i + 1) % n]
        d3 = unit((V[(i + 2) % n][0] - nxt[0], V[(i + 2) % n][1] - nxt[1]))
        T3 = min(R_FIL * math.tan(math.acos(max(-1, min(1, d2[0] * d3[0] + d2[1] * d3[1]))) / 2), 600.0)
        S3 = (nxt[0] - d3[0] * T3, nxt[1] - d3[1] * T3)
        seg = math.hypot(S3[0] - E[0], S3[1] - E[1])
        for k in range(1, max(1, int(seg / 30))):
            t = k / max(1, int(seg / 30))
            chain.append((E[0] + (S3[0] - E[0]) * t, E[1] + (S3[1] - E[1]) * t))
    # بستن حلقه + بازنمونه‌برداری با گام ثابت
    chain.append(chain[0])
    dense = []
    step = 40.0
    carry = 0.0
    for i in range(len(chain) - 1):
        ax, ay = chain[i]
        bx, by = chain[i + 1]
        seg = math.hypot(bx - ax, by - ay)
        t = carry
        while t < seg:
            dense.append((ax + (bx - ax) * t / seg, ay + (by - ay) * t / seg))
            t += step
        carry = t - seg
    return dense, arc_idx, step

PTS, ARC_IDX, PSTEP = build_centerline()
TRACK_LEN = len(PTS) * PSTEP

def path_at(s):
    s = s % TRACK_LEN
    i = int(s / PSTEP) % len(PTS)
    j = (i + 1) % len(PTS)
    t = (s - i * PSTEP) / PSTEP
    return (PTS[i][0] + (PTS[j][0] - PTS[i][0]) * t, PTS[i][1] + (PTS[j][1] - PTS[i][1]) * t)

def path_dir(s):
    i = int(s / PSTEP) % len(PTS)
    j = (i + 1) % len(PTS)
    return unit((PTS[j][0] - PTS[i][0], PTS[j][1] - PTS[i][1]))

def ribbon_poly(half):
    n = len(PTS)
    left, right = [], []
    for i in range(n):
        p = PTS[i]
        d = unit((PTS[(i + 1) % n][0] - PTS[(i - 1) % n][0], PTS[(i + 1) % n][1] - PTS[(i - 1) % n][1]))
        nx, ny = -d[1], d[0]
        left.append((p[0] + nx * half, p[1] + ny * half))
        right.append((p[0] - nx * half, p[1] - ny * half))
    return left + right[::-1]

def near_road_dist(p, skip_s=-1.0):
    """کمترین فاصله تا مسیر؛ skip_s: بخش ۵۰۰ واحدی اطراف مبدأ خود نقطه نادیده
    گرفته می‌شود (چراغِ کنار جاده نباید با جاده‌ی خودش حساب شود!)."""
    best = 1e9
    for i in range(len(PTS)):
        ps = i * PSTEP
        if skip_s >= 0:
            dd = abs(ps - skip_s)
            dd = min(dd, TRACK_LEN - dd)
            if dd < 500:
                continue
        dx = p[0] - PTS[i][0]
        dy = p[1] - PTS[i][1]
        d2 = dx * dx + dy * dy
        if d2 < best:
            best = d2
    return math.sqrt(best)

# ─────────────────── چیدمان شهر ───────────────────
RNG = random.Random(20261013)
buildings, solids, lamps, trees, parked, crosswalks = [], [], [], [], [], []

def place_buildings():
    step = 470.0
    for side in (1, -1):
        s = 320.0
        while s < TRACK_LEN - 320.0:
            if s > 700 and s < TRACK_LEN - 700:
                pass
                w = RNG.uniform(200, 380)
                h = RNG.uniform(170, 330)
                hd = math.hypot(w, h) / 2
                off = WALK_HALF + 46 + hd + RNG.uniform(30, 150)
                d = path_dir(s)
                nx, ny = -d[1] * side, d[0] * side
                p = path_at(s)
                pos = (p[0] + nx * off, p[1] + ny * off)
                ok = near_road_dist(pos) > hd + ROAD_HALF + 24
                ok = ok and abs(pos[0] - RECT[0]) > hd and abs(pos[0] - RECT[2]) > hd
                ok = ok and abs(pos[1] - RECT[1]) > hd and abs(pos[1] - RECT[3]) > hd
                for b in buildings:
                    if math.hypot(b["pos"][0] - pos[0], b["pos"][1] - pos[1]) < (hd + b["hd"]) * 0.82:
                        ok = False
                        break
                if ok:
                    rot = math.degrees(math.atan2(d[1], d[0])) + RNG.uniform(-3, 3)
                    col = ROOF_COLS[RNG.randrange(len(ROOF_COLS))]
                    neon = NEON_COLS[RNG.randrange(len(NEON_COLS))] if RNG.random() < 0.55 else None
                    neon2 = NEON_COLS[RNG.randrange(len(NEON_COLS))]
                    buildings.append({"pos": pos, "rot": rot, "w": w, "h": h, "hd": hd,
                                      "col": col, "neon": neon, "neon2": neon2,
                                      "kind": RNG.randrange(3), "seed": RNG.randrange(9999),
                                      "src_s": s})
            s += step * RNG.uniform(0.8, 1.25)
place_buildings()
for _ in range(900):
    if len(buildings) > 84:
        break
    w = RNG.uniform(190, 340)
    h = RNG.uniform(160, 300)
    hd = math.hypot(w, h) / 2
    pos = (RNG.uniform(RECT[0] + hd + 30, RECT[2] - hd - 30), RNG.uniform(RECT[1] + hd + 30, RECT[3] - hd - 30))
    if near_road_dist(pos) > hd + ROAD_HALF + 24:
        ok = all(math.hypot(b["pos"][0] - pos[0], b["pos"][1] - pos[1]) > (hd + b["hd"]) * 0.92 for b in buildings)
        if ok:
            buildings.append({"pos": pos, "rot": RNG.uniform(0, 90), "w": w, "h": h, "hd": hd,
                              "col": ROOF_COLS[RNG.randrange(len(ROOF_COLS))],
                              "neon": None, "neon2": NEON_COLS[0], "kind": RNG.randrange(3),
                              "seed": RNG.randrange(9999)})

s = 700.0
while s < TRACK_LEN - 400.0:
    d = path_dir(s)
    sgn = 1.0 if int(s / 620) % 2 == 0 else -1.0
    p = path_at(s)
    lamps.append({"pos": (p[0] - d[1] * (ROAD_HALF + 14) * sgn, p[1] + d[0] * (ROAD_HALF + 14) * sgn), "s": s})
    s += 620.0
s = 300.0
tside = 1.0
while s < TRACK_LEN - 300.0:
    d = path_dir(s)
    p = path_at(s)
    trees.append({"pos": (p[0] - d[1] * (WALK_HALF - 22) * tside, p[1] + d[0] * (WALK_HALF - 22) * tside),
                  "r": RNG.uniform(22, 34), "s": s})
    tside *= -1.0
    s += 470.0
s = 900.0
while s < TRACK_LEN - 700.0:
    crosswalks.append(s)
    s += 1500.0
s = 820.0
pside = 1.0
while s < TRACK_LEN - 900.0:
    if all(abs(s - c) > 280 for c in crosswalks):
        d = path_dir(s)
        p = path_at(s + 110)
        parked.append({"pos": (p[0] - d[1] * (ROAD_HALF + 26) * pside, p[1] + d[0] * (ROAD_HALF + 26) * pside),
                       "rot": math.degrees(math.atan2(d[1], d[0])), "s": s})
    pside *= -1.0
    s += 1180.0
# فیلتر امنیتی — فقط برخورد با «بازوی دیگر» مسیر حذف می‌شود (نه جای خود مانع)
lamps = [L for L in lamps if near_road_dist(L["pos"], L["s"]) > ROAD_HALF + 20]
trees = [T for T in trees if near_road_dist(T["pos"], T["s"]) > ROAD_HALF + 40]
parked = [P for P in parked if near_road_dist(P["pos"], P["s"]) > ROAD_HALF + 44]
for T in trees:
    solids.append([round(T["pos"][0], 1), round(T["pos"][1], 1), 18])
for L in lamps:
    solids.append([round(L["pos"][0], 1), round(L["pos"][1], 1), 7])
for P in parked:
    solids.append([round(P["pos"][0], 1), round(P["pos"][1], 1), 46])
for b in buildings:
    b["pos"] = (round(b["pos"][0], 1), round(b["pos"][1], 1))

print("city:", len(buildings), "bld /", len(lamps), "lamp /", len(trees), "tree /", len(parked), "parked  track=", int(TRACK_LEN))

# ─────────────────── اسپرایت‌های پیش‌ساخته ───────────────────
def make_roof_sprite(b):
    w, h = int(b["w"]), int(b["h"])
    m = 44
    img = Image.new("RGBA", (w + m * 2, h + m * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bx0, by0 = m, m
    # سایه‌ی نرم
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rectangle([bx0 + 8, by0 + 10, bx0 + w + 8, by0 + h + 10], fill=(0, 0, 5, 150))
    sh = sh.filter(ImageFilter.GaussianBlur(7))
    img = Image.alpha_composite(img, sh)
    d = ImageDraw.Draw(img)
    # بدنه‌ی پشت‌بام
    col = b["col"]
    d.rectangle([bx0, by0, bx0 + w, by0 + h], fill=col + (255,))
    # کادر ناودانی (پاراپت)
    edge = tuple(min(255, int(c * 1.7 + 12)) for c in col)
    d.rectangle([bx0, by0, bx0 + w, by0 + h], outline=edge + (255,), width=5)
    d.rectangle([bx0 + 7, by0 + 7, bx0 + w - 7, by0 + h - 7], outline=tuple(int(c * 0.7) for c in col) + (255,), width=2)
    rnd = random.Random(b["seed"])
    # بافت بام — خطوط کف‌سازی
    for yy in range(by0 + 14, by0 + h - 10, 22):
        a = 14 if (yy // 22) % 2 == 0 else 8
        d.line([(bx0 + 8, yy), (bx0 + w - 8, yy)], fill=(255, 255, 255, a), width=1)
    # کولرها و فن‌ها
    for k in range(rnd.randrange(2, 5)):
        ax = rnd.randint(bx0 + 24, bx0 + w - 44)
        ay = rnd.randint(by0 + 24, by0 + h - 44)
        d.rectangle([ax, ay, ax + 26, ay + 22], fill=(24, 25, 32, 255), outline=(52, 54, 66, 255), width=2)
        d.ellipse([ax + 5, ay + 4, ax + 21, ay + 18], outline=(70, 73, 86, 255), width=2)
        d.ellipse([ax + 11, ay + 9, ax + 15, ay + 13], fill=(90, 94, 108, 255))
    # روزنه/اسکای‌لایت
    if rnd.random() < 0.5:
        sx = rnd.randint(bx0 + 20, max(bx0 + 21, bx0 + w - 70))
        sy = rnd.randint(by0 + 20, max(by0 + 21, by0 + h - 40))
        d.rectangle([sx, sy, sx + 44, sy + 16], fill=(90, 130, 160, 255), outline=(140, 180, 205, 255), width=2)
    # منبع آب
    if rnd.random() < 0.45:
        wx = rnd.randint(bx0 + 30, max(bx0 + 31, bx0 + w - 60))
        wy = rnd.randint(by0 + 30, max(by0 + 31, by0 + h - 60))
        d.ellipse([wx, wy, wx + 34, wy + 34], fill=(28, 30, 38, 255), outline=(58, 62, 74, 255), width=3)
        d.ellipse([wx + 8, wy + 8, wx + 26, wy + 26], outline=(48, 52, 64, 255), width=2)
    # نور گرم پنجره‌ها — لبه‌ی رو به خیابان (سمت ۰ همان بالای اسپرایت)
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rectangle([bx0 - 6, by0 - 6, bx0 + w + 6, by0 + 16], fill=(255, 200, 120, 40))
    if b["kind"] == 1:
        gd.rectangle([bx0 - 6, by0 + h - 16, bx0 + w + 6, by0 + h + 6], fill=(255, 200, 120, 30))
    glow = glow.filter(ImageFilter.GaussianBlur(6))
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    # نئون لبه
    if b["neon"]:
        nc = b["neon"]
        strip = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(strip)
        sd.rectangle([bx0 + 10, by0 + 2, bx0 + w - 10, by0 + 6], fill=nc + (255,))
        sd.rectangle([bx0 + 10, by0 + h - 6, bx0 + w - 10, by0 + h - 2], fill=nc + (200,))
        hal = Image.new("RGBA", img.size, (0, 0, 0, 0))
        hd2 = ImageDraw.Draw(hal)
        hd2.rectangle([bx0 + 2, by0 - 8, bx0 + w - 2, by0 + 14], fill=nc + (110,))
        hal = hal.filter(ImageFilter.GaussianBlur(10))
        img = Image.alpha_composite(img, hal)
        img = Image.alpha_composite(img, strip)
    # تابلو بام (نوع ۲)
    if b["kind"] == 2:
        nc = b["neon2"]
        sw = min(120, w - 30)
        sx = bx0 + (w - sw) // 2
        img2 = Image.new("RGBA", img.size, (0, 0, 0, 0))
        id2 = ImageDraw.Draw(img2)
        id2.rectangle([sx, by0 + 8, sx + sw, by0 + 26], fill=nc + (235,))
        hal2 = img2.filter(ImageFilter.GaussianBlur(9))
        img = Image.alpha_composite(img, hal2)
        img = Image.alpha_composite(img, img2)
    return img

def make_tree_sprite(r):
    sz = int(r * 3.2)
    img = Image.new("RGBA", (sz, sz), (0, 0, 0, 0))
    cx = cy = sz / 2
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - r + 4, cy - r + 6, cx + r + 4, cy + r + 6], fill=(0, 0, 4, 130))
    sh = sh.filter(ImageFilter.GaussianBlur(4))
    img = Image.alpha_composite(img, sh)
    d = ImageDraw.Draw(img)
    rnd = random.Random(int(r * 100))
    for k in range(6):
        a = k / 6 * math.tau + rnd.uniform(-0.3, 0.3)
        rr = r * rnd.uniform(0.62, 0.88)
        ox, oy = math.cos(a) * r * 0.3, math.sin(a) * r * 0.3
        d.ellipse([cx + ox - rr, cy + oy - rr, cx + ox + rr, cy + oy + rr], fill=(16, 34, 22, 255))
    d.ellipse([cx - r * 0.7, cy - r * 0.7, cx + r * 0.7, cy + r * 0.7], fill=(22, 46, 30, 255))
    d.ellipse([cx - r * 0.45, cy - r * 0.5, cx + r * 0.1, cy + r * 0.05], fill=(38, 70, 46, 220))
    d.ellipse([cx - r * 0.16, cy - r * 0.16, cx + r * 0.16, cy + r * 0.16], fill=(12, 26, 17, 255))
    return img

ROOF_SPRITES = [make_roof_sprite(b) for b in buildings]
TREE_SPRITES = [make_tree_sprite(T["r"]) for T in trees]
CAR_SPR = {}
for cid in ("traf_white", "traf_gray", "traf_taxi"):
    CAR_SPR[cid] = Image.open(os.path.join(OUT, cid + "_top.png")).convert("RGBA")

# ─────────────────── رندر چهارک ───────────────────
QUADS = [(0, 0), (1, 0), (0, 1), (1, 1)]
QW = (RECT[2] - RECT[0]) / 2
QH = (RECT[3] - RECT[1]) / 2
MARGIN = 80.0

def render_quad(qx, qy):
    ox = RECT[0] + qx * QW - MARGIN
    oy = RECT[1] + qy * QH - MARGIN
    vw = int((QW + MARGIN * 2) * SS)
    vh = int((QH + MARGIN * 2) * SS)
    img = Image.new("RGB", (vw, vh), (9, 10, 16))
    d = ImageDraw.Draw(img)

    def T(p):
        return ((p[0] - ox) * SS, (p[1] - oy) * SS)

    # بلوک‌های شهری زیر ساختمان‌ها
    blk = random.Random(777)
    bx = RECT[0]
    while bx < RECT[2]:
        by = RECT[1]
        while by < RECT[3]:
            c = (15 + blk.randrange(2), 17 + blk.randrange(2), 25 + blk.randrange(3))
            d.rectangle([T((bx + 6, by + 6)), T((bx + 322, by + 280))], fill=c)
            by += 292
        bx += 336
    # پیاده‌رو
    d.polygon([T(p) for p in ribbon_poly(WALK_HALF)], fill=(44, 47, 60))
    # درزهای بتن — عمود بر مسیر هر ۳۶px
    s = 0.0
    while s < TRACK_LEN:
        p = path_at(s)
        dv = path_dir(s)
        for sgn in (1, -1):
            a = (p[0] - dv[1] * ROAD_HALF * sgn, p[1] + dv[0] * ROAD_HALF * sgn)
            b = (p[0] - dv[1] * WALK_HALF * sgn, p[1] + dv[0] * WALK_HALF * sgn)
            d.line([T(a), T(b)], fill=(36, 39, 50), width=SS)
        s += 36
    # جدول — لبه‌ی روشن
    d.line([T(p) for p in ribbon_poly(ROAD_HALF + 3)], fill=(74, 78, 94), width=6 * SS, joint="curve")
    # آسفالت
    d.polygon([T(p) for p in ribbon_poly(ROAD_HALF)], fill=(28, 29, 36))
    # نوارهای سایش لاین
    for off in (-62, 62):
        band = []
        for i in range(len(PTS)):
            p = PTS[i]
            dv = path_dir(i * PSTEP)
            nx, ny = -dv[1], dv[0]
            band.append((p[0] + nx * off - dv[0] * 17, p[1] + ny * off - dv[1] * 17))
        d.line([T(p) for p in band], fill=(21, 22, 28), width=34 * SS, joint="curve")
    # وصله و ترک
    rnd = random.Random(4242)
    s = 280.0
    while s < TRACK_LEN - 300.0:
        p = path_at(s)
        dv = path_dir(s)
        nx, ny = -dv[1], dv[0]
        off = rnd.uniform(-85, 85)
        pc = (p[0] + nx * off, p[1] + ny * off)
        pw, ph = rnd.uniform(90, 190), rnd.uniform(40, 80)
        ang = math.atan2(dv[1], dv[0]) + rnd.uniform(-0.5, 0.5)
        ca, sa = math.cos(ang), math.sin(ang)
        pts = []
        for dx, dy in ((-pw / 2, -ph / 2), (pw / 2, -ph / 2), (pw / 2, ph / 2), (-pw / 2, ph / 2)):
            pts.append(T((pc[0] + dx * ca - dy * sa, pc[1] + dx * sa + dy * ca)))
        lite = rnd.random() < 0.4
        d.polygon(pts, fill=(34, 35, 42) if lite else (24, 25, 31))
        s += rnd.uniform(360, 520)
    s = 300.0
    while s < TRACK_LEN - 300.0:
        p = path_at(s)
        dv = path_dir(s)
        nx, ny = -dv[1], dv[0]
        pc = (p[0] + nx * rnd.uniform(-80, 80), p[1] + ny * rnd.uniform(-80, 80))
        cx, cy = T(pc)
        d.ellipse([cx - 12 * SS, cy - 12 * SS, cx + 12 * SS, cy + 12 * SS], fill=(23, 24, 30))
        d.ellipse([cx - 12 * SS, cy - 12 * SS, cx + 12 * SS, cy + 12 * SS], outline=(40, 41, 50), width=2 * SS)
        s += 760
    # خط‌کشی
    for off in (-116, 116):
        band = []
        for i in range(len(PTS)):
            p = PTS[i]
            dv = path_dir(i * PSTEP)
            nx, ny = -dv[1], dv[0]
            band.append((p[0] + nx * off, p[1] + ny * off))
        d.line([T(p) for p in band], fill=(148, 152, 164), width=5 * SS, joint="curve")
    for off in (-5, 5):
        band = []
        for i in range(len(PTS)):
            p = PTS[i]
            dv = path_dir(i * PSTEP)
            nx, ny = -dv[1], dv[0]
            band.append((p[0] + nx * off, p[1] + ny * off))
        d.line([T(p) for p in band], fill=(120, 100, 38), width=4 * SS, joint="curve")
    # خط‌چین لاین
    s = 0.0
    while s < TRACK_LEN:
        p = path_at(s)
        dv = path_dir(s)
        nx, ny = -dv[1], dv[0]
        for off in (-62, 62):
            a = (p[0] + nx * off, p[1] + ny * off)
            b = (a[0] + dv[0] * 52, a[1] + dv[1] * 52)
            d.line([T(a), T(b)], fill=(120, 122, 134), width=4 * SS)
        s += 128
    # گذرگاه عابر
    for cw in crosswalks:
        p = path_at(cw)
        dv = path_dir(cw)
        nx, ny = -dv[1], dv[0]
        off = -ROAD_HALF + 26
        while off < ROAD_HALF - 26:
            a = (p[0] + nx * off - dv[0] * 15, p[1] + ny * off - dv[1] * 15)
            b = (p[0] + nx * off + dv[0] * 15, p[1] + ny * off + dv[1] * 15)
            d.line([T(a), T(b)], fill=(150, 154, 166), width=15 * SS)
            off += 42
    # آجر قرمز/سفید بیرون پیچ‌ها
    for i in sorted(ARC_IDX):
        if (i - 1) in ARC_IDX and (i + 1) in ARC_IDX and i % 3 != 0:
            continue
        p = PTS[i % len(PTS)]
        dv = path_dir(i * PSTEP)
        nx, ny = -dv[1], dv[0]
        dv2 = path_dir((i + 8) * PSTEP)
        cross = dv[0] * dv2[1] - dv[1] * dv2[0]
        sgn = 1 if cross > 0 else -1
        a = (p[0] + nx * sgn * (ROAD_HALF - 12), p[1] + ny * sgn * (ROAD_HALF - 12))
        b = (p[0] + nx * sgn * (ROAD_HALF + 8), p[1] + ny * sgn * (ROAD_HALF + 8))
        col = (150, 44, 34) if (i // 3) % 2 == 0 else (138, 140, 148)
        d.line([T(a), T(b)], fill=col, width=10 * SS)
    # خط شروع — شطرنجی + گرید
    st = path_at(0)
    sd = path_dir(0)
    sn = (-sd[1], sd[0])
    cell = 30.0
    for row in range(2):
        for c in range(8):
            px0 = st[0] + sn[0] * (-ROAD_HALF + c * 32.5 + 4) + sd[0] * row * cell
            py0 = st[1] + sn[1] * (-ROAD_HALF + c * 32.5 + 4) + sd[1] * row * cell
            col = (210, 210, 216) if (row + c) % 2 == 0 else (18, 18, 24)
            poly = [T((px0, py0)), T((px0 + sn[0] * 30, py0 + sn[1] * 30)),
                    T((px0 + sn[0] * 30 + sd[0] * cell, py0 + sn[1] * 30 + sd[1] * cell)),
                    T((px0 + sd[0] * cell, py0 + sd[1] * cell))]
            d.polygon(poly, fill=col)
    for gi, goff in enumerate((-70, 70)):
        s0 = 60 + gi * 70
        p = path_at(s0)
        dv = path_dir(s0)
        nn = (-dv[1], dv[0])
        c0 = (p[0] + nn[0] * goff - dv[0] * 55, p[1] + nn[1] * goff - dv[1] * 55)
        poly = [T(c0), T((c0[0] + dv[0] * 110, c0[1] + dv[1] * 110)),
                T((c0[0] + dv[0] * 110 + nn[0] * 52, c0[1] + dv[1] * 110 + nn[1] * 52)),
                T((c0[0] + nn[0] * 52, c0[1] + nn[1] * 52))]
        d.line(poly + [poly[0]], fill=(110, 112, 124), width=3 * SS, joint="curve")

    img = img.convert("RGBA")

    def paste_rot(base, spr, pos, ang_deg):
        r = spr.rotate(-ang_deg + 90, expand=True, resample=Image.BICUBIC)
        px, py = T(pos)
        base.paste(r, (int(px - r.size[0] / 2), int(py - r.size[1] / 2)), r)

    import os as _os
    if _os.environ.get("BAKE_DEBUG"):
        img.convert("RGB").crop((1000, 600, 1800, 1400)).save("/home/z/my-project/scripts/dbg_2_marks.png")
    # استخر نور چراغ خیابان
    for L in lamps:
        pool = radial_pool(210)
        px, py = T(L["pos"])
        img.alpha_composite(pool, (int(px - 105), int(py - 105)))
    # ماشین‌های پارک‌شده
    for i, P in enumerate(parked):
        paste_rot(img, CAR_SPR[["traf_white", "traf_gray", "traf_taxi"][i % 3]], P["pos"], P["rot"])
    # درخت‌ها
    for i, Tr in enumerate(trees):
        paste_rot(img, TREE_SPRITES[i], Tr["pos"], 0)
    # ساختمان‌ها
    for i, b in enumerate(buildings):
        paste_rot(img, ROOF_SPRITES[i], b["pos"], b["rot"])
    # هسته‌ی چراغ‌ها (بالا برای دیده‌شدن)
    d = ImageDraw.Draw(img)
    for L in lamps:
        px, py = T(L["pos"])
        d.ellipse([px - 5 * SS, py - 5 * SS, px + 5 * SS, py + 5 * SS], fill=(255, 232, 170, 255))
        d.ellipse([px - 8 * SS, py - 8 * SS, px + 8 * SS, py + 8 * SS], fill=(255, 220, 140, 90))
    # درخشش فیروزه‌ای خط شروع
    p = path_at(0)
    dv = path_dir(0)
    nn = (-dv[1], dv[0])
    a = (p[0] + nn[0] * (ROAD_HALF + 16), p[1] + nn[1] * (ROAD_HALF + 16))
    b2 = (p[0] - nn[0] * (ROAD_HALF + 16), p[1] - nn[1] * (ROAD_HALF + 16))
    gl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(gl).line([T(a), T(b2)], fill=(90, 210, 255, 46), width=60 * SS)
    gl = gl.filter(ImageFilter.GaussianBlur(16 * SS / 2))
    img = Image.alpha_composite(img, gl)

    if _os.environ.get("BAKE_DEBUG"):
        img.convert("RGB").crop((1000, 600, 1800, 1400)).save("/home/z/my-project/scripts/dbg_3_pasted.png")
    # دان‌اسکیل به مقیاس تایل + برش دقیق
    img = img.resize((int(img.size[0] * DS / SS), int(img.size[1] * DS / SS)), Image.LANCZOS)
    if _os.environ.get("BAKE_DEBUG"):
        img.convert("RGB").save("/home/z/my-project/scripts/dbg_4_resized.png")
        print("DBG sizes: vw,vh=", vw, vh, " resized=", img.size, " ox,oy=", ox, oy)
    cw, chh = int(QW * DS), int(QH * DS)
    cx0 = int(round(MARGIN * DS))
    cy0 = int(round(MARGIN * DS))
    tile = img.crop((cx0, cy0, cx0 + cw, cy0 + chh))
    # دانه‌ی نهایی
    arr = np.asarray(tile, dtype=np.int16)
    g = np.random.RandomState(qx * 3 + qy + 9).randint(-4, 4, (chh, cw, 1), dtype=np.int16)
    arr = np.clip(arr + g, 0, 255).astype(np.uint8)
    tile = Image.fromarray(arr.astype(np.uint8)[:, :, :3], "RGB")
    tile.save(os.path.join(OUT, f"map_{qy * 2 + qx}.png"))
    print("tile", qy * 2 + qx, tile.size)

def radial_pool(size):
    yy, xx = np.mgrid[0:size, 0:size]
    dist = np.sqrt((xx - size / 2) ** 2 + (yy - size / 2) ** 2) / (size / 2)
    a = np.clip(1 - dist, 0, 1) ** 2.2 * 92
    arr = np.zeros((size, size, 4), dtype=np.uint8)
    arr[:, :, 0] = 255
    arr[:, :, 1] = 226
    arr[:, :, 2] = 168
    arr[:, :, 3] = a.astype(np.uint8)
    return Image.fromarray(arr, "RGBA")

for qx, qy in QUADS:
    render_quad(qx, qy)

# ─────────────────── JSON ───────────────────
os.makedirs(DATA, exist_ok=True)
layout = {
    "meta": {
        "rect": list(RECT), "scale": DS, "road_half": ROAD_HALF, "walk_half": WALK_HALF,
        "track_len": TRACK_LEN, "pstep": PSTEP,
        "start": {"pos": [path_at(0)[0], path_at(0)[1]], "ang": math.degrees(math.atan2(path_dir(0)[1], path_dir(0)[0]))},
        "world_min": [RECT[0] + 60, RECT[1] + 60], "world_max": [RECT[2] - 60, RECT[3] - 60],
    },
    "centerline": [[round(x, 1), round(y, 1)] for x, y in PTS],
    "buildings": [[b["pos"][0], b["pos"][1], round(b["rot"], 2), round(b["w"], 1), round(b["h"], 1)] for b in buildings],
    "solids": solids,
    "lamps": [[round(L["pos"][0], 1), round(L["pos"][1], 1)] for L in lamps],
    "parked": [[P["pos"][0], P["pos"][1], round(P["rot"], 2)] for P in parked],
    "crosswalks": [round(c, 1) for c in crosswalks],
}
with open(os.path.join(DATA, "city_layout.json"), "w") as f:
    json.dump(layout, f)
print("json saved —", os.path.getsize(os.path.join(DATA, "city_layout.json")) // 1024, "KB")
