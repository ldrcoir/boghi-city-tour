#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پچ دوم gen16_map.py — تراکم واقعی: دیوار پیوسته، ردیف ۲ و ۳، پرشدن بلوک، حذف سیاه‌چال‌ها."""
import io

P = "/home/z/my-project/scripts/gen16_map.py"
src = io.open(P, encoding="utf-8").read()

# ─── ۱) ردیف اول: پیوسته‌تر (گپ کم) ───
old = """            ok = near_road_dist(pos, skip_s=s) > ROAD_HALF + max(w, depth) / 2 + 80
            ok = ok and RECT[0] + 30 < pos[0] < RECT[2] - 30 and RECT[1] + 30 < pos[1] < RECT[3] - 30
            for b in buildings:
                if math.hypot(b["pos"][0] - pos[0], b["pos"][1] - pos[1]) < (hd + b["hd"]) * 0.60:
                    ok = False
                    break
            if ok:
                rot = math.degrees(math.atan2(d[1], d[0])) + RNG.uniform(-2.5, 2.5)"""
new = """            ok = near_road_dist(pos, skip_s=s) > ROAD_HALF + max(w, depth) / 2 + 80
            ok = ok and RECT[0] + 30 < pos[0] < RECT[2] - 30 and RECT[1] + 30 < pos[1] < RECT[3] - 30
            for b in buildings:
                if math.hypot(b["pos"][0] - pos[0], b["pos"][1] - pos[1]) < (hd + b["hd"]) * 0.52:
                    ok = False
                    break
            if ok:
                rot = math.degrees(math.atan2(d[1], d[0])) + RNG.uniform(-2.5, 2.5)"""
assert old in src, "row1"
src = src.replace(old, new, 1)
src = src.replace("            s += w + RNG.uniform(10, 40)", "            s += w + RNG.uniform(6, 20)", 1)

# ─── ۲) ردیف دوم: احتمال بالاتر، چسب‌تر ───
old2 = """            if RNG.random() < 0.62:
                ok = near_road_dist(pos, skip_s=s) > ROAD_HALF + max(w, depth) / 2 + 80
                ok = ok and RECT[0] + 30 < pos[0] < RECT[2] - 30 and RECT[1] + 30 < pos[1] < RECT[3] - 30
                for b in buildings:
                    if math.hypot(b["pos"][0] - pos[0], b["pos"][1] - pos[1]) < (hd + b["hd"]) * 0.74:"""
new2 = """            if RNG.random() < 0.85:
                ok = near_road_dist(pos, skip_s=s) > ROAD_HALF + max(w, depth) / 2 + 80
                ok = ok and RECT[0] + 30 < pos[0] < RECT[2] - 30 and RECT[1] + 30 < pos[1] < RECT[3] - 30
                for b in buildings:
                    if math.hypot(b["pos"][0] - pos[0], b["pos"][1] - pos[1]) < (hd + b["hd"]) * 0.60:"""
assert old2 in src, "row2"
src = src.replace(old2, new2, 1)
src = src.replace("            s += w + RNG.uniform(20, 80)", "            s += w + RNG.uniform(12, 40)", 1)

# ─── ۳) ردیف سوم + پرکردن درونی نزدیک‌تر ───
old3 = """    # ۳) پرکردن درون بلوک‌ها — شبکه‌ی لَچ‌دار + حیاط سبز
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
                if ok:"""
new3 = """    # ۳) پرکردن درون بلوک‌ها — شبکه‌ی متراکم + حیاط سبز
    step = 235.0
    rix = 0
    gy = RECT[1] + 120
    while gy < RECT[3] - 120:
        gx = RECT[0] + 120 + (step * 0.5 if rix % 2 else 0.0)
        while gx < RECT[2] - 120:
            r = RNG.random()
            w = RNG.uniform(150, 280)
            h = RNG.uniform(140, 250)
            hd = math.hypot(w, h) / 2
            pos = (gx + RNG.uniform(-50, 50), gy + RNG.uniform(-50, 50))
            far = near_road_dist(pos)
            near_alley = any(math.hypot(A["pos"][0] - pos[0], A["pos"][1] - pos[1]) < 250 for A in alleys)
            if r < 0.78 and not near_alley and far - max(w, h) / 2 > WALK_HALF + 8:
                ok = True
                for b in buildings:
                    if math.hypot(b["pos"][0] - pos[0], b["pos"][1] - pos[1]) < (hd + b["hd"]) * 0.66:
                        ok = False
                        break
                if ok:"""
assert old3 in src, "interior"
src = src.replace(old3, new3, 1)

# ─── ۴) حیاط سبز — قابل دیدن‌تر ───
old4 = """            elif r < 0.80 and not near_alley and far > ROAD_HALF + 280:
                greens.append({"pos": pos, "r": RNG.uniform(55, 105)})"""
new4 = """            elif r < 0.90 and not near_alley and far > WALK_HALF + 140:
                greens.append({"pos": pos, "r": RNG.uniform(48, 92)})"""
assert old4 in src, "greens"
src = src.replace(old4, new4, 1)

# ─── ۵) حذف سیاه‌چال بین بلوک‌ها — زمین پیوسته ───
old5 = """    # بلوک‌های شهری زیر ساختمان‌ها
    blk = random.Random(777)
    bx = RECT[0]
    while bx < RECT[2]:
        by = RECT[1]
        while by < RECT[3]:
            c = (15 + blk.randrange(2), 17 + blk.randrange(2), 25 + blk.randrange(3))
            d.rectangle([T((bx + 6, by + 6)), T((bx + 322, by + 280))], fill=c)
            by += 292
        bx += 336"""
new5 = """    # زمین شهری پیوسته + تن بلوک‌ها (بدون سیاه‌چال شبکه‌ای)
    blk = random.Random(777)
    d.rectangle([T((RECT[0] - 50, RECT[1] - 50)), T((RECT[2] + 50, RECT[3] + 50))], fill=(14, 15, 22))
    bx = RECT[0]
    while bx < RECT[2]:
        by = RECT[1]
        while by < RECT[3]:
            c = (17 + blk.randrange(4), 19 + blk.randrange(4), 27 + blk.randrange(5))
            d.rectangle([T((bx + 2, by + 2)), T((bx + 334, by + 290))], fill=c)
            by += 292
        bx += 336"""
assert old5 in src, "blocks"
src = src.replace(old5, new5, 1)

io.open(P, "w", encoding="utf-8").write(src)
import py_compile
py_compile.compile(P, doraise=True)
print("density patch OK")
