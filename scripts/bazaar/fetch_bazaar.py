#!/usr/bin/env python3
"""Fetch Cafe Bazaar game categories and extract app title+package pairs."""
import re, html, subprocess, os, json, sys

BASE = "https://cafebazaar.ir"
OUT = "/home/z/my-project/scripts/bazaar"
UA = "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 Chrome/120 Mobile"

CATS = {
    "racing": "ماشین‌بازی",
    "arcade": "آرکید",
    "casual": "کژوال",
    "adventure": "ماجرایی",
    "puzzle": "پازل",
    "action": "اکشن",
}

def fetch(cat):
    path = os.path.join(OUT, f"{cat}.html")
    if not os.path.exists(path) or os.path.getsize(path) < 10000:
        subprocess.run(["curl", "-sL", "--max-time", "25", "-A", UA,
                        f"{BASE}/cat/{cat}", "-o", path], check=False)
    return open(path, encoding="utf-8").read()

def parse(src):
    # pattern: <a href="/app/<pkg>" ...><picture alt="TITLE">
    pairs = re.findall(
        r'href="/app/([\w.]+)"[^>]*class="[^"]*SimpleAppItem[^"]*"[^>]*>.*?<picture[^>]*alt="([^"]+)"',
        src, re.S)
    if not pairs:
        pairs = re.findall(
            r'<picture[^>]*alt="([^"]+)"[\s\S]{0,600}?href="/app/([\w.]+)"', src, re.S)
        pairs = [(b, a) for a, b in pairs]
    seen, out = set(), []
    for pkg, title in pairs:
        if pkg not in seen:
            seen.add(pkg)
            out.append((pkg, html.unescape(title)))
    return out

all_results = {}
for cat, fa in CATS.items():
    src = fetch(cat)
    apps = parse(src)
    all_results[cat] = apps
    print(f"\n=== {fa} ({cat}) — {len(apps)} بازی ===")
    for pkg, title in apps[:20]:
        print(f"  {title}  [{pkg}]")

json.dump(all_results, open(os.path.join(OUT, "all_cats.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
print("\nsaved -> all_cats.json")
