#!/usr/bin/env python3
"""Chroma-key magenta background out of game sprites, trim, resize, save to game assets."""
import os
from PIL import Image, ImageFilter

RAW = "/home/z/my-project/scripts/sprites_raw"
OUT = "/home/z/my-project/game/assets/sprites"
os.makedirs(OUT, exist_ok=True)

# target widths in px for game world
TARGET_W = {
    "boghi_side.png": 420,
    "sharare_side.png": 440,
    "zabib_side.png": 470,
    "coin.png": 120,
    "cone.png": 130,
    "passenger.png": 180,
    "ramp.png": 300,
}

def key_out_magenta(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # magenta family: red AND blue both well above green
            if r > g + 50 and b > g + 25:
                px[x, y] = (r, g, b, 0)
    # trim colored fringe: erode alpha, then feather it
    alpha = img.getchannel("A").filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
    img.putalpha(alpha)
    return img

def trim(img: Image.Image) -> Image.Image:
    bbox = img.getbbox()
    return img.crop(bbox) if bbox else img

def process(name):
    path = os.path.join(RAW, name)
    img = Image.open(path)
    img = key_out_magenta(img)
    img = trim(img)
    tw = TARGET_W.get(name)
    if tw and img.width > tw:
        th = int(img.height * tw / img.width)
        img = img.resize((tw, th), Image.LANCZOS)
    # slight alpha edge cleanup
    img = img.filter(ImageFilter.SMOOTH)
    dst = os.path.join(OUT, name)
    img.save(dst)
    print(f"{name:22s} -> {img.size}")

for n in TARGET_W:
    process(n)

# background: keep as-is but resize to 1920 wide
bg = Image.open(os.path.join(RAW, "bg_tehran.png")).convert("RGB")
bg = bg.resize((1920, int(bg.height * 1920 / bg.width)), Image.LANCZOS)
bg.save(os.path.join(OUT, "bg_tehran.png"), quality=92)
print("bg_tehran.png          ->", bg.size)

# game icon: square center-crop of boghi, rounded look (engine will scale)
ic = Image.open(os.path.join(OUT, "boghi_side.png"))
side = ic.height
cx = ic.width // 2
sq = ic.crop((max(0, cx - side // 2), 0, min(ic.width, cx + side // 2), side))
sq = sq.resize((256, 256), Image.LANCZOS)
# put on soft sky background circle
canvas = Image.new("RGBA", (256, 256), (120, 200, 255, 255))
canvas.alpha_composite(sq, ((256 - sq.width) // 2, (256 - sq.height) // 2))
canvas.save("/home/z/my-project/game/icon.png")
print("icon.png saved")

print("DONE")
