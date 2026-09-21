#!/usr/bin/env python3
"""Prep sprites for AI face edit: pad onto magenta canvas, remember crop box."""
from PIL import Image
import os, json

BASE = "/home/z/my-project"
os.makedirs(f"{BASE}/scripts/face_edit", exist_ok=True)

def prep(src, out, canvas=(1152, 864), scale_to_w=1040):
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    s = min(scale_to_w / w, (canvas[1] - 80) / h, 1.6)
    im2 = im.resize((int(w * s), int(h * s)), Image.LANCZOS)
    mag = Image.new("RGBA", canvas, (255, 0, 255, 255))
    x = (canvas[0] - im2.width) // 2
    y = (canvas[1] - im2.height) // 2
    mag.paste(im2, (x, y), im2)
    mag.convert("RGB").save(out)
    return {"src": src, "out": out, "x": x, "y": y, "w": im2.width, "h": im2.height, "orig": (w, h), "scale": s}

jobs = []
# 1) red boghi side view (the hero face fix)
jobs.append(prep(f"{BASE}/game/assets/sprites/boghi_side.png", f"{BASE}/scripts/face_edit/boghi_mag.png"))
# 2) app icon (front view boghi)
ic = Image.open(f"{BASE}/game/icon.png")
jobs.append(prep(f"{BASE}/game/icon.png", f"{BASE}/scripts/face_edit/icon_mag.png", canvas=(1024, 1024), scale_to_w=880))
# 3) pride: racing eyes + speckle cleanup
jobs.append(prep(f"{BASE}/game/assets/sprites/pride_side.png", f"{BASE}/scripts/face_edit/pride_mag.png"))

with open(f"{BASE}/scripts/face_edit/boxes.json", "w") as f:
    json.dump(jobs, f, indent=1)
for j in jobs:
    print(j["out"], j["w"], "x", j["h"], "at", j["x"], j["y"])
