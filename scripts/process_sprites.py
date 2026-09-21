#!/usr/bin/env python3
"""Painterly asset pipeline for Boghi: smart bg removal (magenta auto-detect +
edge flood-fill), layer prep (parallax far/mid/road), sprite trimming, icon."""
import os
import numpy as np
import cv2
from PIL import Image, ImageFilter

RAW = "/home/z/my-project/scripts/sprites_raw"
OUT = "/home/z/my-project/game/assets/sprites"
os.makedirs(OUT, exist_ok=True)

TARGET_W = {
    "boghi_side.png": 420, "sharare_side.png": 440, "zabib_side.png": 470,
    "sepand_side.png": 400, "arian_side.png": 480, "shahin_side.png": 480,
    "ezhdeha_side.png": 470, "shaparak_side.png": 380, "karvan_side.png": 490,
    "coin.png": 120, "cone.png": 130, "passenger.png": 180, "ramp.png": 300,
    "plate_empty.png": 800,
}
LAYER_W = 1920  # saved width for full-frame layers


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
    return float(((r > g + 50) & (b > g + 25)).mean()) > 0.30


def key_magenta(rgb):
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    return np.where((r > g + 50) & (b > g + 25), 0, 255).astype(np.uint8)


def cluster_bg_key(rgb, k=8, T=40.0, lum_floor=70.0):
    """Remove colors close to border-color clusters, but only where they connect
    to the border AND are not dark (protects tires, outlines, dark details)."""
    h, w = rgb.shape[:2]
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]).astype(np.float32)
    rng = np.random.default_rng(7)
    idx = rng.choice(len(border), size=min(4000, len(border)), replace=False)
    crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 1.0)
    _, _, centers = cv2.kmeans(border[idx], k, None, crit, 4, cv2.KMEANS_PP_CENTERS)
    flat = rgb.reshape(-1, 3).astype(np.float32)
    dmin = np.full(flat.shape[0], 1e9, np.float32)
    for c in centers:
        dmin = np.minimum(dmin, np.linalg.norm(flat - c[None, :], axis=1))
    lum = flat.mean(axis=1)
    bgmask = ((dmin < T) & (lum > lum_floor)).reshape(h, w).astype(np.uint8)
    n, lab = cv2.connectedComponents(bgmask, 8)
    border_labels = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
    border_labels.discard(0)
    keep = np.isin(lab, list(border_labels))
    return np.where(keep, 0, 255).astype(np.uint8)


def make_hills():
    """Procedural painterly silhouette hills (mid parallax layer)."""
    import random
    from PIL import ImageDraw
    random.seed(11)
    W, H = 1344, 430
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)

    def hill_layer(ybase, amp, color):
        n = 8
        ys = [ybase + random.uniform(-amp, amp) for _ in range(n + 1)]
        ys[-1] = ys[0]  # match border heights -> seamless mirror tiling
        for _ in range(3):  # smooth
            ys = [ys[0]] + [(ys[i - 1] + 2 * ys[i] + ys[i + 1]) / 4 for i in range(1, n)] + [ys[n]]
        pts = [(0, H)] + [(int(i * W / n), int(y)) for i, y in enumerate(ys)] + [(W, H)]
        dr.polygon(pts, fill=color)

    hill_layer(165, 55, (150, 168, 137, 255))   # back hill — dusty sage
    hill_layer(255, 60, (122, 146, 109, 255))   # front hill
    for i in range(6):  # poplar silhouettes
        x = 100 + i * 225 + random.randint(-45, 45)
        base = 300 + random.randint(-30, 35)
        hgt = random.randint(130, 200)
        dr.ellipse([x - 36, base - hgt, x + 36, base + 10], fill=(101, 126, 92, 255))
        dr.rectangle([x - 4, base - 15, x + 4, base + 60], fill=(88, 111, 81, 255))
    img.save(os.path.join(OUT, "bg_mid.png"))
    print(f"bg_mid.png             -> procedural {img.size}")


def drop_fragments(alpha, frac=0.12):
    """Keep the main blob + sizable pieces; drop small leftover bg fragments."""
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


def keyed_sprite(name, top_only=False, tol=9):
    rgb = load_rgb(name)
    method = "magenta" if is_magenta_bg(rgb) else "cluster"
    alpha = key_magenta(rgb) if method == "magenta" else cluster_bg_key(rgb)
    alpha = drop_fragments(alpha_clean(alpha))
    print(f"  {name}: {method} key")
    rgba = trim_rgba(np.dstack([rgb, alpha]))
    save_img(rgba, name, TARGET_W.get(name))


# ---------- cutout sprites: cars, items, name-board ----------
for n in ["boghi_side.png", "sharare_side.png", "zabib_side.png",
          "sepand_side.png", "arian_side.png", "shahin_side.png",
          "ezhdeha_side.png", "shaparak_side.png", "karvan_side.png",
          "coin.png", "cone.png", "passenger.png", "ramp.png"]:
    keyed_sprite(n)
keyed_sprite("plate_empty.png")  # white paper bg -> sticker

# ---------- full-frame layers ----------
for n in ["bg_sky.png", "menu_bg.png", "bg_far.png"]:
    save_img(load_rgb(n), n, LAYER_W)

# mid hills: procedural painterly silhouette (reliable + coherent depth)
make_hills()

# road: crop the painted road band (avoid top sky band / bottom flowers)
rgb = load_rgb("road_strip.png")
h = rgb.shape[0]
band = rgb[int(h * 0.345):int(h * 0.660), :, :]
save_img(band, "road_strip.png", LAYER_W)

# ---------- game icon ----------
ic = Image.open(os.path.join(OUT, "boghi_side.png"))
side = ic.height
cx = ic.width // 2
sq = ic.crop((max(0, cx - side // 2), 0, min(ic.width, cx + side // 2), side)).resize((256, 256), Image.LANCZOS)
canvas = Image.new("RGBA", (256, 256), (244, 196, 48, 255))
canvas.alpha_composite(sq, ((256 - sq.width) // 2, (256 - sq.height) // 2))
canvas.save("/home/z/my-project/game/icon.png")
print("icon.png saved")
print("DONE")
