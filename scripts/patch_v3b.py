#!/usr/bin/env python3
"""Patch v3b: hard crop road band, key purple sky out of bg_mid, key new ustad."""
import os
import numpy as np
import cv2
from PIL import Image, ImageFilter

RAW = "/home/z/my-project/scripts/sprites_raw_v3"
OUT = "/home/z/my-project/game/assets/sprites"


def load_raw(name):
    return np.array(Image.open(os.path.join(RAW, name)).convert("RGB"))


def save(arr, name, target_w=None):
    img = Image.fromarray(arr)
    if target_w and img.width > target_w:
        img = img.resize((target_w, int(img.height * target_w / img.width)), Image.LANCZOS)
    if img.mode == "RGBA":
        img = img.filter(ImageFilter.SMOOTH)
    img.save(os.path.join(OUT, name))
    print(name, "->", img.size)


# ---------- road: crop maroon wall + bottom vignette, opaque ----------
road = load_raw("road_strip.png")
save(road[95:745], "road_strip.png", 1920)

# ---------- bg_mid: key magenta AND purple sky, band crop ----------
mid = load_raw("bg_mid.png").astype(int)
r, g, b = mid[..., 0], mid[..., 1], mid[..., 2]
mag = (r > g + 40) & (b > g + 15)
purple = (b > g + 30) & (b > r + 12) & (b > 110)
alpha = np.where(mag | purple, 0, 255).astype(np.uint8)
alpha = cv2.GaussianBlur(alpha, (5, 5), 1.0)
ys, _ = np.where(alpha > 10)
top, bot = int(ys.min()), int(ys.max()) + 1
save(np.dstack([mid.astype(np.uint8), alpha])[top:bot], "bg_mid.png", 1920)

# ---------- ustad: magenta key ----------
def key_magenta(rgb):
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    return np.where((r > g + 40) & (b > g + 15), 0, 255).astype(np.uint8)


ust = load_raw("ustad.png")
a = key_magenta(ust)
a = cv2.erode(a, np.ones((3, 3), np.uint8), iterations=2)
a = cv2.GaussianBlur(a, (5, 5), 1.2)
n, lab, stats, _ = cv2.connectedComponentsWithStats((a > 10).astype(np.uint8), 8)
if n > 1:
    areas = stats[1:, cv2.CC_STAT_AREA]
    big = 1 + int(np.argmax(areas))
    keep = {big}
    for i in range(1, n):
        if i != big and stats[i, cv2.CC_STAT_AREA] >= 0.12 * float(areas.max()):
            keep.add(i)
    a = np.where(np.isin(lab, list(keep)), a, 0).astype(np.uint8)
rgba = np.dstack([ust, a])
ys, xs = np.where(rgba[..., 3] > 10)
rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
save(rgba, "ustad.png", 340)
print("PATCH DONE")
