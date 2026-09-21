#!/usr/bin/env python3
"""Extract real user reviews (AppCommentsList__item) + screenshots for research apps."""
import re, subprocess, os, json, html as H

OUT = "/home/z/my-project/scripts/bazaar/research"
os.makedirs(OUT + "/shots", exist_ok=True)
UA = "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 Chrome/120 Mobile"

def fa2en(s):
    return s.translate(str.maketrans("۰۱۲۳۴۵۶۷۸۹٪", "0123456789%"))

def parse(pkg):
    path = f"{OUT}/app_{pkg}.html"
    if not os.path.exists(path) or os.path.getsize(path) < 5000:
        subprocess.run(["curl", "-sL", "--max-time", "25", "-A", UA,
                        f"https://cafebazaar.ir/app/{pkg}", "-o", path], check=False)
    src = open(path, encoding="utf-8").read()
    t = re.search(r'<picture class="AppIcon" alt="([^"]+)"', src)
    votes = re.search(r'- ([\d،,]+) رأی', src)
    rv = re.search(r'([\d\.]+) از ۵', src)
    blocks = re.split(r'<div class="AppComment AppCommentsList__item"', src)[1:]
    reviews = []
    for b in blocks:
        un = re.search(r'AppComment__username">([^<]+)<', b)
        wd = re.search(r'rating__fill" style="width:(\d+)%', b)
        dt = re.search(r'(\d{4}/\d{2}/\d{2})', b)
        body = re.search(r'AppComment__body fs-14">([^<]+)<', b)
        lk = re.search(r' likes="(\d+)"', b)
        if body:
            stars = round(int(wd.group(1)) / 20) if wd else None
            reviews.append({
                "user": H.unescape(un.group(1)).strip() if un else "?",
                "stars": stars, "date": dt.group(1) if dt else "",
                "likes": int(lk.group(1)) if lk else 0,
                "text": H.unescape(re.sub(r"\s+", " ", body.group(1))).strip()})
    # screenshot urls
    urls = re.findall(r'(https://s\d+\.cafebazaar\.ir[^"\'\s\\]+?(?:screenshot|pic)[^"\'\s\\]+)', src)
    urls = [u.replace("\\u0026", "&").replace("\\/", "/") for u in urls]
    seen, finals = set(), []
    for u in urls:
        base = u.split("?")[0]
        if base not in seen:
            seen.add(base); finals.append(u)
    for i, u in enumerate(finals[:6]):
        subprocess.run(["curl", "-sL", "--max-time", "20", "-A", UA, u,
                        "-o", f"{OUT}/shots/{pkg.replace('.','_')}_{i}.webp"], check=False)
    return {"pkg": pkg, "votes": votes.group(1) if votes else "?",
            "rating": rv.group(1) if rv else "?",
            "n_shown": len(reviews), "reviews": reviews}

targets = ["ir.nomogame.ClutchGame", "com.MagicalGames.DrifterDriver",
           "com.com.mydrift1401.MyDrift", "com.StudioAvanGame.SafheClutch"]
out = {}
for pkg in targets:
    out[pkg] = parse(pkg)
    d = out[pkg]
    print(f"\n===== {pkg}  | رأی: {d['votes']} | امتیاز: {d['rating']} | نظرات نمایش‌داده‌شده: {d['n_shown']}")
    for r in d["reviews"][:10]:
        print(f"  ({r['stars']}★){' ['+str(r['likes'])+' لایک]' if r['likes']>5 else ''} {r['text'][:160]}")

json.dump(out, open(OUT + "/addictive_games.json", "w"), ensure_ascii=False, indent=1)
print("\nsaved -> addictive_games.json ; shots in research/shots/")
