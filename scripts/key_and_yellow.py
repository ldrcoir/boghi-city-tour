#!/usr/bin/env python3
"""Key magenta out of AI-edited car sprites -> transparent PNGs.
Also builds: fixed boghi_side.png, matching icon.png, yellow sibling car."""
from PIL import Image, ImageFilter
import numpy as np, os, colorsys

BASE = "/home/z/my-project"
FE = f"{BASE}/scripts/face_edit"

def key_magenta(img: Image.Image, m_thresh=28, hard=90) -> Image.Image:
    """Alpha from magenta-ness m = min(R,B) - G; also kill purple-hued dark shadow."""
    im = img.convert("RGBA")
    a = np.asarray(im).astype(np.int16)
    R, G, B, A = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    m = np.minimum(R, B) - G
    alpha = np.clip((m_thresh - m) / max(1, (m_thresh + hard - 2 * m_thresh)), 0, 1)
    # smooth ramp: m<=m_thresh -> opaque ; m>=m_thresh+hard -> transparent
    alpha = np.clip((m_thresh + hard - m) / hard, 0, 1)
    # purple shadow kill: hue 0.72..0.93 with value<0.55
    mx = a[..., :3].max(axis=2) / 255.0
    mn = a[..., :3].min(axis=2) / 255.0
    delta = (mx - mn) + 1e-6
    hue = np.zeros_like(mx)
    r_, g_, b_ = R / 255.0, G / 255.0, B / 255.0
    mask_mx = mx == r_ * 255 / 255.0
    # vector hue calc (float 0..1)
    rr, gg, bb = mx, mn, mx  # placeholders
    hue = np.where(mx == r_, ((gg - bb) / delta) % 6, hue)
    hue = np.where(mx == gg, (bb - rr) / delta + 2, hue)
    hue = np.where((mx == bb) & (mx != r_) & (mx != gg), (rr - gg) / delta + 4, hue)
    hue = hue / 6.0
    purple = (hue > 0.70) & (hue < 0.94) & (mx < 0.60)
    alpha[purple] = 0.0
    # despill: where semi-magenta, pull R,B toward G
    spill = (m > 10) & (m <= m_thresh + hard)
    Rp, Gp, Bp = a[..., 0].astype(np.float32), a[..., 1].astype(np.float32), a[..., 2].astype(np.float32)
    avg = (Rp + Bp) / 2.0
    Rp[spill] = np.minimum(Rp[spill], (avg + Gp)[spill] / 2 * 0.9 + Rp[spill] * 0.1)
    Bp[spill] = np.minimum(Bp[spill], (avg + Gp)[spill] / 2 * 0.9 + Bp[spill] * 0.1)
    a[..., 0], a[..., 2] = Rp.astype(np.int16), Bp.astype(np.int16)
    a[..., 3] = (alpha * 255).astype(np.int16)
    out = Image.fromarray(a.astype(np.uint8), "RGBA")
    # soften alpha edge
    out.putalpha(out.getchannel("A").filter(ImageFilter.GaussianBlur(0.6)))
    return out

def trim(im: Image.Image, pad=6) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    l = max(0, l - pad); t = max(0, t - pad)
    r = min(im.width, r + pad); b = min(im.height, b + pad)
    return im.crop((l, t, r, b))

# ---------- 1) boghi ----------
boghi = key_magenta(Image.open(f"{FE}/boghi_ai.png"))
boghi = trim(boghi)
boghi.save(f"{FE}/boghi_fixed.png")
print("boghi_fixed:", boghi.size)

# ---------- 2) icon from fixed boghi (front 3/4) ----------
icon_car = boghi.copy()
# warm gradient background like the classic icon (dark maroon -> orange)
W = H = 512
bg = Image.new("RGBA", (W, H))
top = (58, 16, 12); bot = (244, 132, 40)
px = np.zeros((H, W, 4), dtype=np.uint8)
for yy in range(H):
    t = yy / (H - 1)
    c = [int(top[i] + (bot[i] - top[i]) * t) for i in range(3)] + [255]
    px[yy, :] = c
bg = Image.fromarray(px, "RGBA")
car = icon_car.copy()
car.thumbnail((440, 440), Image.LANCZOS)
bg.paste(car, ((W - car.width) // 2, H - car.height - 18), car)
bg.convert("RGB").resize((256, 256), Image.LANCZOS).save(f"{BASE}/game/icon.png")
bg.convert("RGB").save(f"{FE}/icon_fixed_512.png")
print("icon rebuilt")

# ---------- 3) yellow sibling ----------
im = boghi.convert("RGBA")
a = np.asarray(im).astype(np.float32) / 255.0
R, G, B = a[..., 0], a[..., 1], a[..., 2]
mx = a[..., :3].max(axis=2); mn = a[..., :3].min(axis=2)
delta = mx - mn + 1e-6
hue = np.zeros_like(mx)
r_, g_, b_ = R, G, B
hue = np.where(mx == r_, ((g_ - b_) / delta) % 6, hue)
hue = np.where(mx == g_, (b_ - r_) / delta + 2, hue)
hue = np.where((mx == b_) & (mx != r_) & (mx != g_), (r_ - g_) / delta + 4, hue)
hue = hue / 6.0
sat = delta / (mx + 1e-6)
# red band (0.90..1.05 wrap) & saturated & not too dark -> shift to golden 0.115
redband = ((hue > 0.90) | (hue < 0.03)) & (sat > 0.28) & (mx > 0.16)
newhue = np.where(redband, 0.115, hue)
# rebuild HSV -> RGB
v = mx; s = sat; h6 = newhue * 6.0
i = np.floor(h6).astype(int) % 6
f = h6 - np.floor(h6)
p = v * (1 - s); q = v * (1 - f * s); t = v * (1 - (1 - f) * s)
r2 = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [v, q, p, p, t, v])
g2 = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [t, v, v, q, p, p])
b2 = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [p, p, t, v, v, q])
out = np.stack([r2, g2, b2, a[..., 3]], axis=-1)
yellow = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
yellow = trim(yellow)
yellow.save(f"{BASE}/game/assets/sprites/boghi_yellow_side.png")
print("yellow saved:", yellow.size)

# replace in-game boghi (keep name/path so all scenes update)
boghi.save(f"{BASE}/game/assets/sprites/boghi_side.png")
print("boghi_side.png replaced:", boghi.size)

# contact sheet for review
sheet = Image.new("RGB", (1200, 560), (235, 235, 235))
bb = boghi.resize((int(560 * boghi.width / boghi.height), 540)) if boghi.height > 0 else boghi
bb.thumbnail((560, 540))
yb = yellow.copy(); yb.thumbnail((560, 540))
icf = Image.open(f"{FE}/icon_fixed_512.png").resize((256, 256))
sheet.paste(bb, (10, 10), bb)
sheet.paste(yb, (620, 10), yb)
sheet.paste(icf, (620, 290))
sheet.save(f"{FE}/review_sheet.png")
print("review sheet saved")
