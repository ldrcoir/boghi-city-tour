#!/usr/bin/env python3
"""Processing v2: chroma-key new semi-realistic cars + items, full-frame layers,
auto-crop road band, tree band cutout, fresh game icon."""
import os
import numpy as np
import cv2
from PIL import Image, ImageFilter

RAW = "/home/z/my-project/scripts/sprites_raw_v2"
OUT = "/home/z/my-project/game/assets/sprites"
os.makedirs(OUT, exist_ok=True)

TARGET_W = {
    "boghi_side.png": 440, "pride_side.png": 460, "dena_side.png": 480,
    "shahin_side.png": 480, "tiba_side.png": 430, "pejo_side.png": 450,
    "samand_side.png": 470, "nissan_side.png": 500, "quick_side.png": 440,
    "coin.png": 130, "cone.png": 130, "passenger.png": 190, "ramp.png": 300,
}
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


def is_magenta_bg(rgb):
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]).astype(int)
    r, g, b = border[..., 0], border[..., 1], border[..., 2]
    return float(((r > g + 40) & (b > g + 15)).mean()) > 0.25


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


def keyed_sprite(name):
    rgb = load_rgb(name)
    assert is_magenta_bg(rgb), f"{name}: magenta bg not detected!"
    alpha = drop_fragments(alpha_clean(key_magenta(rgb)))
    rgba = trim_rgba(np.dstack([rgb, alpha]))
    save_img(rgba, name, TARGET_W.get(name))
    return rgba


def full_frame(name):
    save_img(load_rgb(name), name, LAYER_W)


def road_band(name):
    rgb = load_rgb(name)
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    mag = (r > g + 40) & (b > g + 15)
    rowmag = mag.mean(axis=1)
    band_rows = np.where(rowmag < 0.5)[0]
    top, bot = int(band_rows.min()), int(band_rows.max()) + 1
    band = rgb[top:bot]
    save_img(band, name, LAYER_W)


def tree_band(name):
    rgb = load_rgb(name)
    alpha = key_magenta(rgb)
    alpha = cv2.GaussianBlur(alpha, (5, 5), 1.0)
    ys, _ = np.where(alpha > 10)
    top, bot = int(ys.min()), int(ys.max()) + 1
    rgba = np.dstack([rgb, alpha])[top:bot]
    save_img(rgba, name, LAYER_W)


# cars
CARS = ["boghi_side.png", "pride_side.png", "dena_side.png", "shahin_side.png",
        "tiba_side.png", "pejo_side.png", "samand_side.png", "nissan_side.png",
        "quick_side.png"]
for n in CARS:
    keyed_sprite(n)
# items
for n in ["coin.png", "cone.png", "passenger.png", "ramp.png"]:
    keyed_sprite(n)
# layers
full_frame("bg_sky.png")
full_frame("bg_far.png")
full_frame("menu_bg.png")
tree_band("bg_mid.png")
road_band("road_strip.png")

# game icon from new mascot
ic = Image.open(os.path.join(OUT, "boghi_side.png"))
side = ic.height
cx = ic.width // 2
sq = ic.crop((max(0, cx - side // 2), 0, min(ic.width, cx + side // 2), side)).resize((256, 256), Image.LANCZOS)
canvas = Image.new("RGBA", (256, 256), (24, 26, 34, 255))
canvas.alpha_composite(sq, ((256 - sq.width) // 2, (256 - sq.height) // 2))
canvas.save("/home/z/my-project/game/icon.png")
print("icon.png saved")
print("DONE")
