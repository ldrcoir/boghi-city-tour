#!/usr/bin/env python3
"""Processing v3: glossy painted environment + ustad character.
- keyed_sprite: ustad.png (magenta chroma-key)
- full_frame: bg_far.png, menu_bg.png (overwrite in game assets)
- band cutouts: bg_mid.png (buildings), road_strip.png (glossy road)
- fresh icon: boghi car on sunset gradient
"""
import os
import numpy as np
import cv2
from PIL import Image, ImageFilter

RAW = "/home/z/my-project/scripts/sprites_raw_v3"
OUT = "/home/z/my-project/game/assets/sprites"
os.makedirs(OUT, exist_ok=True)

LAYER_W = 1920


def load_rgb(name):
    return np.array(Image.open(os.path.join(RAW, name)).convert("RGB"))


def save_img(arr, name, target_w=None):
    img = Image.fromarray(arr)
    if target_w and img.width > target_w:
        img = img.resize((target_w, int(img.height * target_w / img.width)), Image.LANCZOS)
    if img.mode == "RGBA":
        img = img.filter(ImageFilter.SMOOTH)
    img.save(os.path.join(OUT, name), quality=92)
    print(f"{name:22s} -> {img.size}")


def alpha_clean(alpha):
    a = cv2.erode(alpha, np.ones((3, 3), np.uint8), iterations=2)
    return cv2.GaussianBlur(a, (5, 5), 1.2)


def key_magenta(rgb):
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    return np.where((r > g + 40) & (b > g + 15), 0, 255).astype(np.uint8)


def drop_fragments(alpha, frac=0.12):
    n, lab, stats, _ = cv2.connectedComponentsWithStats((alpha > 10).astype(np.uint8), 8)
    if n <= 1:
        return alpha
    areas = stats[1:, cv2.CC_STAT_AREA]
    big = 1 + int(np.argmax(areas))
    keep = {big}
    for i in range(1, n):
        if i != big and stats[i, cv2.CC_STAT_AREA] >= frac * float(areas.max()):
            keep.add(i)
    return np.where(np.isin(lab, list(keep)), alpha, 0).astype(np.uint8)


def trim_rgba(arr):
    ys, xs = np.where(arr[..., 3] > 10)
    if len(xs) == 0:
        return arr
    return arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def keyed_sprite(name, target_w=420):
    rgb = load_rgb(name)
    alpha = drop_fragments(alpha_clean(key_magenta(rgb)))
    rgba = trim_rgba(np.dstack([rgb, alpha]))
    save_img(rgba, name, target_w)


def full_frame(name):
    save_img(load_rgb(name), name, LAYER_W)


def band_cutout(name, min_frac=0.5):
    """Magenta above+below band -> alpha; crop to content rows."""
    rgb = load_rgb(name)
    alpha = key_magenta(rgb)
    alpha = cv2.GaussianBlur(alpha, (5, 5), 1.0)
    ys, _ = np.where(alpha > 10)
    if len(ys) == 0:
        print(f"!! {name}: nothing keyed, saving full frame")
        save_img(rgb, name, LAYER_W)
        return
    top, bot = int(ys.min()), int(ys.max()) + 1
    rgba = np.dstack([rgb, alpha])[top:bot]
    save_img(rgba, name, LAYER_W)


# استاد فنر
keyed_sprite("ustad.png", 300)
# لایه‌های تمام‌قاب
full_frame("bg_far.png")
full_frame("menu_bg.png")
# باند ساختمان‌ها و جاده
band_cutout("bg_mid.png")
band_cutout("road_strip.png")

# آیکون: ماشین بوقی روی گرادیان غروب
car = Image.open(os.path.join(OUT, "boghi_side.png")).convert("RGBA")
side = car.height
cx = car.width // 2
sq = car.crop((max(0, cx - side // 2), 0, min(car.width, cx + side // 2), side))
grad = np.zeros((256, 256, 3), dtype=np.uint8)
top_c, bot_c = np.array([36, 28, 74]), np.array([244, 138, 46])
for y in range(256):
    t = y / 255.0
    grad[y] = (top_c * (1 - t) + bot_c * t).astype(np.uint8)
canvas = Image.fromarray(grad).convert("RGBA")
sq_r = sq.resize((210, 210), Image.LANCZOS)
canvas.alpha_composite(sq_r, ((256 - 210) // 2, (256 - 210) // 2))
canvas.save("/home/z/my-project/game/icon.png")
print("icon.png saved")
print("DONE")
