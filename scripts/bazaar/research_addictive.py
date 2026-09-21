#!/usr/bin/env python3
"""Research: find Drift/Clutch games + cash-reward games on Cafe Bazaar.
Extract installs, ratings, description, review snippets, screenshot URLs."""
import re, subprocess, os, json, html, urllib.parse

OUT = "/home/z/my-project/scripts/bazaar/research"
os.makedirs(OUT, exist_ok=True)
UA = "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 Chrome/120 Mobile"

def get(url, name):
    path = os.path.join(OUT, name)
    if not os.path.exists(path) or os.path.getsize(path) < 3000:
        subprocess.run(["curl", "-sL", "--max-time", "25", "-A", UA, url, "-o", path], check=False)
    try:
        return open(path, encoding="utf-8").read()
    except Exception:
        return ""

def search(q, tag):
    url = "https://cafebazaar.ir/search/?q=" + urllib.parse.quote(q)
    src = get(url, f"search_{tag}.html")
    pairs = re.findall(r'href="/app/([\w.]+)"[^>]*>.*?<picture[^>]*alt="([^"]+)"', src, re.S)
    seen, out = set(), []
    for pkg, title in pairs:
        if pkg not in seen:
            seen.add(pkg)
            out.append((pkg, html.unescape(title).strip()))
    return out[:8]

def stats(pkg):
    src = get(f"https://cafebazaar.ir/app/{pkg}", f"app_{pkg}.html")
    t = re.search(r'<picture[^>]*alt="([^"]+)"', src)
    title = html.unescape(t.group(1)).strip() if t else "?"
    m = re.search(r'نصب</td><td class="InfoCube__content fs-14">(?:<!--\[-->)?([^<]+)', src)
    installs = m.group(1).strip() if m else "?"
    r = re.search(r'([\d\.]+)\s*星级|ratingValue["\']?\s*:\s*["\']([\d\.]+)', src)
    r2 = re.search(r'"ratingValue"\s*:\s*"([\d\.]+)"', src)
    rating = r2.group(1) if r2 else (r.group(1) if r else "?")
    # description
    d = re.search(r'<meta name="description" content="([^"]+)"', src)
    desc = html.unescape(d.group(1))[:400] if d else ""
    # screenshots
    shots = re.findall(r'(https://s\d+\.cafebazaar\.ir:?\d*/upload/pic/[^"\'\s\\]+\.webp)', src)
    shots = [s.replace("\\u0026", "&") for s in shots][:8]
    # reviews embedded in page (name + text snippets)
    revs = re.findall(r'"text"\s*:\s*"([^"]{40,300})"', src)
    authors = re.findall(r'"author"\s*:\s*\{[^}]*"name"\s*:\s*"([^"]+)"', src)
    revs = [html.unescape(x).replace("\\u200c", " ") for x in revs[:10]]
    return {"pkg": pkg, "title": title, "installs": installs, "rating": rating,
            "desc": desc, "shots": shots, "reviews": revs[:10], "authors": authors[:10]}

result = {"drift": [], "clutch": [], "cash": []}
for q, key in [("دریفت", "drift"), ("کلاچ", "clutch"),
               ("پول واقعی درآمد", "cash"), ("جایزه نقدی", "cash")]:
    res = search(q, key if key != "cash" else "cash_" + q.replace(" ", "_"))
    result.setdefault(key, [])
    for pkg, title in res:
        if key not in result:
            result[key] = []
        result[key].append({"pkg": pkg, "title": title})

print(json.dumps(result, ensure_ascii=False, indent=1))
json.dump(result, open(os.path.join(OUT, "search_index.json"), "w"), ensure_ascii=False, indent=1)
