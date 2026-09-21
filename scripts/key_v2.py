#!/usr/bin/env python3
"""Hue-based magenta keying v2 — keeps car body intact, rotates interior magenta
fringe to red, fills holes, then rebuilds icon + yellow sibling."""
from PIL import Image, ImageFilter
import numpy as np

BASE = "/home/z/my-project"
FE = f"{BASE}/scripts/face_edit"

def hsv(img):
    a = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    mx = a[..., :3].max(axis=2); mn = a[..., :3].min(axis=2)
    delta = mx - mn + 1e-9
    hue = np.where(mx == R, ((G - B) / delta) % 6,
          np.where(mx == G, (B - R) / delta + 2, (R - G) / delta + 4)) / 6.0
    hue = hue % 1.0
    sat = delta / (mx + 1e-9)
    return a, hue, sat, mx

def key_and_fix(src, out, mlo=0.70, mhi=0.955, smin=0.22):
    a, hue, sat, val = hsv(Image.open(src))
    magentaish = (hue > mlo) & (hue < mhi) & (sat > smin)
    keep = ~magentaish  # car pixels
    # closing to fill interior holes (spokes painted magenta etc.)
    mimg = Image.fromarray((keep * 255).astype(np.uint8))
    closed = mimg.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(7))
    filled = np.asarray(closed) > 127
    # silhouette = filled; alpha soft
    alpha = filled.astype(np.float32)
    alpha_img = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))
    alpha = np.asarray(alpha_img).astype(np.float32) / 255.0
    alpha = np.minimum(alpha, keep.astype(np.float32) * 0.7 + filled.astype(np.float32) * 0.3 + 0.0)
    # interior magenta -> rotate hue to red 0.985, keep value (despill inside car)
    inside_magenta = magentaish & filled
    h2 = np.where(inside_magenta, 0.985, hue)
    s2 = np.where(inside_magenta, np.clip(sat * 0.92, 0, 1), sat)
    # rebuild RGB from H2/S/val
    v, s, h6 = val, s2, h2 * 6.0
    i = np.floor(h6).astype(int) % 6
    f = h6 - np.floor(h6)
    p = v * (1 - s); q = v * (1 - f * s); t = v * (1 - (1 - f) * s)
    r2 = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [v, q, p, p, t, v])
    g2 = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [t, v, v, q, p, p])
    b2 = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [p, p, t, v, v, q])
    outa = np.stack([r2, g2, b2, alpha], axis=-1)
    img = Image.fromarray((np.clip(outa, 0, 1) * 255).astype(np.uint8))
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    img.save(out)
    print(out, img.size)
    return img

boghi = key_and_fix(f"{FE}/boghi_ai.png", f"{FE}/boghi_fixed.png")

# ---- icon: fixed car on warm gradient ----
W = H = 512
top = (58, 16, 12); bot = (244, 132, 40)
yy = np.arange(H).reshape(-1, 1, 1) / (H - 1)
grad = np.concatenate([np.linspace(top[c], bot[c], H).reshape(H, 1).repeat(W, 1)[..., None] for c in range(3)], axis=-1).astype(np.uint8)
bg = Image.fromarray(grad.squeeze()).convert("RGBA")
car = boghi.copy(); car.thumbnail((430, 430), Image.LANCZOS)
bg.paste(car, ((W - car.width) // 2, H - car.height - 20), car)
bg.convert("RGB").resize((256, 256), Image.LANCZOS).save(f"{BASE}/game/icon.png")
bg.convert("RGB").save(f"{FE}/icon_fixed_512.png")

# ---- yellow sibling from fixed red ----
a, hue, sat, val = hsv(boghi)
redband = ((hue > 0.88) | (hue < 0.045)) & (sat > 0.25) & (val > 0.13)
h2 = np.where(redband, 0.118, hue)
v, s, h6 = val, sat, h2 * 6.0
i = np.floor(h6).astype(int) % 6
f = h6 - np.floor(h6)
p = v * (1 - s); q = v * (1 - f * s); t = v * (1 - (1 - f) * s)
r2 = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [v, q, p, p, t, v])
g2 = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [t, v, v, q, p, p])
b2 = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [p, p, t, v, v, q])
yimg = Image.fromarray((np.clip(np.stack([r2, g2, b2, a[..., 3]], -1), 0, 1) * 255).astype(np.uint8))
yimg.save(f"{BASE}/game/assets/sprites/boghi_yellow_side.png")

boghi.save(f"{BASE}/game/assets/sprites/boghi_side.png")

# ---- review sheet on neutral gray ----
sheet = Image.new("RGB", (1240, 600), (225, 225, 225))
bb = boghi.copy(); bb.thumbnail((600, 560)); sheet.paste(bb, (10, 20), bb)
yb = yimg.copy(); yb.thumbnail((600, 560)); sheet.paste(yb, (625, 20), yb)
icf = Image.open(f"{FE}/icon_fixed_512.png").resize((240, 240)); sheet.paste(icf, (985, 350))
sheet.save(f"{FE}/review_sheet2.png")
print("DONE")
