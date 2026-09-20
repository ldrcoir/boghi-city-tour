#!/usr/bin/env python3
"""Fetch Cafe Bazaar app pages to extract install counts and ratings."""
import re, subprocess, os, json, html

OUT = "/home/z/my-project/scripts/bazaar"
UA = "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 Chrome/120 Mobile"

APPS = [
    "com.zibapasandan.toofun2", "com.zibapasandan.toofun", "com.zibapasandan.toofunatashin",
    "com.jds.pridesavari", "com.StudioPartizan.Shetab3", "com.glimgames.taxido",
    "com.karaweb.cartoonracer", "com.MaHooGames.ParkingShow", "com.jalebgame.pejofs",
    "com.StudioAvanGame.SafheClutch", "ir.Clutch_Duel.ag", "com.jalebgame.iranracer",
    "com.yegangame.atomicrider", "ir.MHB.FireTire", "com.xnightstudio.zifan",
]

def fa2num(s):
    trans = str.maketrans("۰۱۲۳۴۵۶۷۸۹٬,", "012345678900")
    return int(s.translate(trans).replace("٬", "").replace(",", ""))

rows = []
for pkg in APPS:
    path = os.path.join(OUT, f"app_{pkg}.html")
    if not os.path.exists(path) or os.path.getsize(path) < 5000:
        subprocess.run(["curl", "-sL", "--max-time", "20", "-A", UA,
                        f"https://cafebazaar.ir/app/{pkg}", "-o", path], check=False)
    try:
        src = open(path, encoding="utf-8").read()
    except Exception:
        continue
    title = ""
    m = re.search(r'<picture[^>]*alt="([^"]+)"', src)
    if m: title = html.unescape(m.group(1))
    installs, rating, votes = "", "", ""
    m = re.search(r'نصب</td><td class="InfoCube__content fs-14">(?:<!--\[-->)?([^<]+)', src)
    if m: installs = m.group(1).strip()
    m = re.search(r'"ratingValue"\s*:\s*([\d.]+)', src)
    if m: rating = m.group(1)
    m = re.search(r'"ratingCount"\s*:\s*(\d+)', src)
    if m: votes = m.group(1)
    if not votes:
        m = re.search(r'از ([\d۰-۹،,]+) رأی', src)
        if m: votes = m.group(1)
    print(f"{title[:35]:38s} | نصب: {installs:15s} | امتیاز: {rating or '-':4s} ({votes or '-'} رأی)")
    rows.append({"pkg": pkg, "title": title, "installs": installs,
                 "rating": rating, "votes": votes})

json.dump(rows, open(os.path.join(OUT, "app_stats.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
