#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پچ gen16_map.py — شهر متراکم واقعی: دیوار ساختمان حاشیه خیابان، ردیف دوم،
پرکردن بلوک، حیاط سبز، کوچه، پنجره‌های روشن، آویز مغازه، پارک متراکم."""
import io

P = "/home/z/my-project/scripts/gen16_map.py"
src = io.open(P, encoding="utf-8").read()
n_orig = len(src)

# ─── ۱) لیست‌های جدید ───
old = "buildings, solids, lamps, trees, parked, crosswalks = [], [], [], [], [], []"
new = ("buildings, solids, lamps, trees, parked, crosswalks = [], [], [], [], [], []\n"
       "greens, alleys = [], []")
assert old in src
src = src.replace(old, new, 1)

# ─── ۲) جایگزینی کامل place_buildings ───
start = src.find("def place_buildings():")
end = src.find("s = 700.0")
assert start != -1 and end != -1 and end > start
NEW_PLACE = '''def place_buildings():
    # ── v0.16: شهر متراکم — دیوار پیوسته‌ی حاشیه خیابان + پرکردن بلوک ──
    # ۱) ردیف اول: ساختمان‌های چسبیده به هم در دو طرف (مغازه/خانه)
    for side in (1, -1):
        s = 130.0
        while s < TRACK_LEN - 130.0:
            w = RNG.uniform(170, 340)
            depth = RNG.uniform(140, 240)
            hd = math.hypot(w, depth) / 2
            off = WALK_HALF + 20 + depth / 2
            d = path_dir(s)
            nx, ny = -d[1] * side, d[0] * side
            p = path_at(s)
            pos = (p[0] + nx * off, p[1] + ny * off)
            if RNG.random() < 0.085:
                alleys.append({"pos": (p[0] + nx * (WALK_HALF + 30 + RNG.uniform(150, 230)),
                                       p[1] + ny * (WALK_HALF + 30 + RNG.uniform(150, 230))),
                               "rot": math.degrees(math.atan2(d[1], d[0])),
                               "len": RNG.uniform(300, 520)})
                s += RNG.uniform(250, 390)
                continue
            ok = near_road_dist(pos, skip_s=s) > ROAD_HALF + max(w, depth) / 2 + 80
            ok = ok and RECT[0] + 30 < pos[0] < RECT[2] - 30 and RECT[1] + 30 < pos[1] < RECT[3] - 30
            for b in buildings:
                if math.hypot(b["pos"][0] - pos[0], b["pos"][1] - pos[1]) < (hd + b["hd"]) * 0.60:
                    ok = False
                    break
            if ok:
                rot = math.degrees(math.atan2(d[1], d[0])) + RNG.uniform(-2.5, 2.5)
                col = ROOF_COLS[RNG.randrange(len(ROOF_COLS))]
                front = RNG.random() < 0.78
                neon = NEON_COLS[RNG.randrange(len(NEON_COLS))] if (front and RNG.random() < 0.62) else None
                neon2 = NEON_COLS[RNG.randrange(len(NEON_COLS))]
                buildings.append({"pos": pos, "rot": rot, "w": w, "h": depth, "hd": hd,
                                  "col": col, "neon": neon, "neon2": neon2,
                                  "kind": 0 if front else RNG.randrange(3),
                                  "awn": front and RNG.random() < 0.6,
                                  "seed": RNG.randrange(9999), "src_s": s, "row": 1})
            s += w + RNG.uniform(10, 40)
    # ۲) ردیف دوم پشت ردیف اول — پشت کوچه‌ی پشتی
    for side in (1, -1):
        s = 200.0
        while s < TRACK_LEN - 200.0:
            w = RNG.uniform(160, 300)
            depth = RNG.uniform(130, 210)
            hd = math.hypot(w, depth) / 2
            off = WALK_HALF + 20 + 310 + depth / 2
            d = path_dir(s)
            nx, ny = -d[1] * side, d[0] * side
            p = path_at(s)
            pos = (p[0] + nx * off, p[1] + ny * off)
            if RNG.random() < 0.62:
                ok = near_road_dist(pos, skip_s=s) > ROAD_HALF + max(w, depth) / 2 + 80
                ok = ok and RECT[0] + 30 < pos[0] < RECT[2] - 30 and RECT[1] + 30 < pos[1] < RECT[3] - 30
                for b in buildings:
                    if math.hypot(b["pos"][0] - pos[0], b["pos"][1] - pos[1]) < (hd + b["hd"]) * 0.74:
                        ok = False
                        break
                if ok:
                    rot = math.degrees(math.atan2(d[1], d[0])) + RNG.uniform(-9, 9)
                    buildings.append({"pos": pos, "rot": rot, "w": w, "h": depth, "hd": hd,
                                      "col": ROOF_COLS[RNG.randrange(len(ROOF_COLS))],
                                      "neon": None, "neon2": NEON_COLS[RNG.randrange(len(NEON_COLS))],
                                      "kind": RNG.randrange(3), "awn": False,
                                      "seed": RNG.randrange(9999), "row": 2})
            s += w + RNG.uniform(20, 80)
    # ۳) پرکردن درون بلوک‌ها — شبکه‌ی لَچ‌دار + حیاط سبز
    step = 300.0
    rix = 0
    gy = RECT[1] + 160
    while gy < RECT[3] - 160:
        gx = RECT[0] + 160 + (step * 0.5 if rix % 2 else 0.0)
        while gx < RECT[2] - 160:
            r = RNG.random()
            w = RNG.uniform(150, 270)
            h = RNG.uniform(140, 240)
            hd = math.hypot(w, h) / 2
            pos = (gx + RNG.uniform(-45, 45), gy + RNG.uniform(-45, 45))
            far = near_road_dist(pos)
            near_alley = any(math.hypot(A["pos"][0] - pos[0], A["pos"][1] - pos[1]) < 270 for A in alleys)
            if r < 0.60 and not near_alley and far > ROAD_HALF + 230 and far - ROAD_HALF - 60 > hd:
                ok = True
                for b in buildings:
                    if math.hypot(b["pos"][0] - pos[0], b["pos"][1] - pos[1]) < (hd + b["hd"]) * 0.85:
                        ok = False
                        break
                if ok:
                    buildings.append({"pos": pos, "rot": RNG.choice((0.0, 90.0, RNG.uniform(0, 90))),
                                      "w": w, "h": h, "hd": hd,
                                      "col": ROOF_COLS[RNG.randrange(len(ROOF_COLS))],
                                      "neon": None, "neon2": NEON_COLS[0],
                                      "kind": RNG.randrange(3), "awn": False,
                                      "seed": RNG.randrange(9999), "row": 3})
            elif r < 0.80 and not near_alley and far > ROAD_HALF + 280:
                greens.append({"pos": pos, "r": RNG.uniform(55, 105)})
            gx += step
        gy += step * 0.9
        rix += 1

'''
src = src[:start] + NEW_PLACE + src[end:]

# ─── ۳) پارک متراکم‌تر ───
old_park = '''s = 820.0
pside = 1.0
while s < TRACK_LEN - 900.0:
    if all(abs(s - c) > 280 for c in crosswalks):
        d = path_dir(s)
        p = path_at(s + 110)
        parked.append({"pos": (p[0] - d[1] * (ROAD_HALF + 26) * pside, p[1] + d[0] * (ROAD_HALF + 26) * pside),
                       "rot": math.degrees(math.atan2(d[1], d[0])), "s": s})
    pside *= -1.0
    s += 1180.0'''
new_park = '''s = 820.0
pside = 1.0
while s < TRACK_LEN - 900.0:
    if all(abs(s - c) > 280 for c in crosswalks):
        d = path_dir(s)
        p = path_at(s + 110)
        parked.append({"pos": (p[0] - d[1] * (ROAD_HALF + 26) * pside, p[1] + d[0] * (ROAD_HALF + 26) * pside),
                       "rot": math.degrees(math.atan2(d[1], d[0])), "s": s})
        if RNG.random() < 0.55 and all(abs(s + 62 - c) > 240 for c in crosswalks):
            p2 = path_at(s + 174)
            parked.append({"pos": (p2[0] - d[1] * (ROAD_HALF + 26) * pside, p2[1] + d[0] * (ROAD_HALF + 26) * pside),
                           "rot": math.degrees(math.atan2(d[1], d[0])), "s": s + 62})
    pside *= -1.0
    s += 430.0'''
assert old_park in src, "park block"
src = src.replace(old_park, new_park, 1)

# ─── ۴) پنجره‌های نما + آویز داخل make_roof_sprite ───
anchor = '''    # کولرها و فن‌ها'''
WIN = '''    # پنجره‌های نمای شب — ردیف روشن دور هر چهار لبه (خیابان‌ها زنده می‌شوند)
    rndw = random.Random(b["seed"] * 7 + 13)
    win_glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    wgd = ImageDraw.Draw(win_glow)
    lit_cols = [(255, 206, 122), (255, 222, 158), (214, 228, 246), (255, 190, 96)]
    def window_edge(x0, y0, x1, y1, horiz):
        if horiz:
            n = max(2, int((x1 - x0) // 20))
            for i in range(n):
                wx = x0 + i * 20 + 5
                if wx + 12 > x1:
                    break
                rr = rndw.random()
                if rr < 0.50:
                    c = lit_cols[rndw.randrange(len(lit_cols))]
                elif rr < 0.62:
                    c = (150, 182, 222)
                else:
                    c = (28, 30, 40)
                wgd.rectangle([wx, y0, wx + 11, y0 + 7], fill=c + (255,))
        else:
            n = max(2, int((y1 - y0) // 20))
            for i in range(n):
                wy = y0 + i * 20 + 5
                if wy + 12 > y1:
                    break
                rr = rndw.random()
                if rr < 0.50:
                    c = lit_cols[rndw.randrange(len(lit_cols))]
                elif rr < 0.62:
                    c = (150, 182, 222)
                else:
                    c = (28, 30, 40)
                wgd.rectangle([x0, wy, x0 + 7, wy + 11], fill=c + (255,))
    ins = 12
    window_edge(bx0 + 10, by0 + ins, bx0 + w - 10, by0 + ins + 7, True)
    window_edge(bx0 + 10, by0 + h - ins - 7, bx0 + w - 10, by0 + h - ins, True)
    window_edge(bx0 + ins, by0 + 12, bx0 + ins + 7, by0 + h - 12, False)
    window_edge(bx0 + w - ins - 7, by0 + 12, bx0 + w - ins, by0 + h - 12, False)
    img = Image.alpha_composite(img, win_glow.filter(ImageFilter.GaussianBlur(3)))
    img = Image.alpha_composite(img, win_glow)
    d = ImageDraw.Draw(img)
    # آویز مغازه — لبه‌ی رو به خیابان (ردیف اول)
    if b.get("awn"):
        aw_cols = [(172, 56, 46), (46, 100, 64), (198, 170, 62), (64, 78, 148), (188, 188, 192)]
        ac = aw_cols[rnd.randrange(len(aw_cols))]
        nst = max(3, int(w // 16))
        for i in range(nst):
            cc = ac if i % 2 == 0 else (232, 228, 220)
            d.rectangle([bx0 + i * 16, by0 - 9, bx0 + i * 16 + 16, by0 - 1], fill=cc + (255,))
        d.line([(bx0, by0 - 1), (bx0 + w, by0 - 1)], fill=(20, 20, 26, 200), width=2)
    # کولرها و فن‌ها'''
assert anchor in src
src = src.replace(anchor, WIN, 1)

# ─── ۵) اسپرایت کوچه ───
anchor2 = "ROOF_SPRITES = [make_roof_sprite(b) for b in buildings]"
ALLEY = '''def make_alley_sprite(length):
    m = 24
    img = Image.new("RGBA", (110 + m * 2, int(length) + m * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([m, m, m + 110, m + int(length)], fill=(23, 24, 31, 255))
    d.line([(m, m), (m + 110, m)], fill=(44, 47, 60, 255), width=4)
    d.line([(m, m + int(length)), (m + 110, m + int(length))], fill=(44, 47, 60, 255), width=4)
    for yy in range(m + 30, m + int(length) - 24, 64):
        d.line([(m + 42, yy), (m + 68, yy)], fill=(96, 98, 110, 200), width=3)
    d.ellipse([m + 10, m + 22, m + 30, m + 42], fill=(34, 40, 36, 255), outline=(60, 68, 62, 255), width=2)
    d.ellipse([m + 80, m + int(length) - 46, m + 100, m + int(length) - 26],
              fill=(42, 38, 34, 255), outline=(68, 62, 56, 255), width=2)
    return img

''' + anchor2
assert anchor2 in src
src = src.replace(anchor2, ALLEY, 1)

# ─── ۶) رندر کوچه و حیاط سبز داخل render_quad (بعد از استخر نور، قبل از پارک) ───
anchor3 = '''    # ماشین‌های پارک‌شده'''
COURT = '''    # کوچه‌ها — گذرهای تاریک بین ساختمان‌ها
    for A in alleys:
        paste_rot(img, make_alley_sprite(A["len"]), A["pos"], A["rot"])
    # حیاط‌های سبز درون بلوک‌ها
    for G in greens:
        gxp, gyp = T(G["pos"])
        rr = G["r"] * SS
        d.ellipse([gxp - rr, gyp - rr * 0.8, gxp + rr, gyp + rr * 0.8], fill=(17, 30, 21))
        d.ellipse([gxp - rr * 0.7, gyp - rr * 0.55, gxp + rr * 0.7, gyp + rr * 0.55], fill=(21, 38, 26))
        for k in range(4):
            ang = k * 1.7 + G["r"]
            ox = math.cos(ang) * rr * 0.55
            oy = math.sin(ang) * rr * 0.5
            tr = rr * 0.22
            d.ellipse([gxp + ox - tr, gyp + oy - tr, gxp + ox + tr, gyp + oy + tr], fill=(26, 46, 30))
    # ماشین‌های پارک‌شده'''
assert anchor3 in src
src = src.replace(anchor3, COURT, 1)

# ─── ۷) پرینت نهایی ───
old_pr = 'print("city:", len(buildings), "bld /", len(lamps), "lamp /", len(trees), "tree /", len(parked), "parked  track=", int(TRACK_LEN))'
new_pr = 'print("city:", len(buildings), "bld /", len(lamps), "lamp /", len(trees), "tree /", len(parked), "parked /", len(alleys), "alley /", len(greens), "green  track=", int(TRACK_LEN))'
assert old_pr in src
src = src.replace(old_pr, new_pr, 1)

io.open(P, "w", encoding="utf-8").write(src)
print("patched:", n_orig, "->", len(src), "bytes")
import py_compile
py_compile.compile(P, doraise=True)
print("syntax OK")
