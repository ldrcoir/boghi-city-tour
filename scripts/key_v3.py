#!/usr/bin/env python3
"""Green-screen keying v3 + interior despill (body->red, wheels->gray)
+ icon rebuild + yellow sibling + review sheet."""
from PIL import Image, ImageFilter
import numpy as np

BASE = "/home/z/my-project"
FE = f"{BASE}/scripts/face_edit"

def hsv_of(a):
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    mx = a[..., :3].max(axis=2); mn = a[..., :3].min(axis=2)
    delta = mx - mn + 1e-9
    hue = np.where(mx == R, ((G - B) / delta) % 6,
          np.where(mx == G, (B - R) / delta + 2, (R - G) / delta + 4)) / 6.0
    return hue % 1.0, delta / (mx + 1e-9), mx

a = np.asarray(Image.open(f"{FE}/boghi_ai2.png").convert("RGBA")).astype(np.float32) / 255.0
hue, sat, val = hsv_of(a)

# --- mask: kill green background & shadow ---
greenish = (hue > 0.24) & (hue < 0.47) & (sat > 0.30)
keep = ~greenish
mimg = Image.fromarray((keep * 255).astype(np.uint8))
closed = np.asarray(mimg.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))) > 127
alpha = closed.astype(np.float32)
ai = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
alpha = np.asarray(ai).astype(np.float32) / 255.0

# --- interior despill ---
inside_green = greenish & closed
on_body = inside_green & (val >= 0.45)
on_dark = inside_green & (val < 0.45)
hue2 = np.where(on_body, 0.985, hue)
sat2 = np.where(on_dark, sat * 0.12, sat)
sat2 = np.where(on_body, np.clip(sat * 1.02, 0, 1), sat2)

def hsv2rgb(h, s, v):
    h6 = h * 6.0
    i = np.floor(h6).astype(int) % 6
    f = h6 - np.floor(h6)
    p = v * (1 - s); q = v * (1 - f * s); t = v * (1 - (1 - f) * s)
    r = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [v, q, p, p, t, v])
    g = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [t, v, v, q, p, p])
    b = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [p, p, t, v, v, q])
    return r, g, b

r2, g2, b2 = hsv2rgb(hue2, sat2, val)
car = Image.fromarray((np.clip(np.stack([r2, g2, b2, alpha], -1), 0, 1) * 255).astype(np.uint8))
car = car.crop(car.getbbox())
car.save(f"{FE}/boghi_fixed.png")
car.save(f"{BASE}/game/assets/sprites/boghi_side.png")
print("boghi:", car.size)

# --- icon ---
H = W = 512
top = (58, 16, 12); bot = (244, 132, 40)
grad = np.zeros((H, W, 4), np.uint8)
for c in range(3):
    grad[..., c] = np.linspace(top[c], bot[c], H).reshape(-1, 1).repeat(W, 1)
bg = Image.fromarray(grad).convert("RGBA")
c2 = car.copy(); c2.thumbnail((420, 420), Image.LANCZOS)
bg.paste(c2, ((W - c2.width) // 2, H - c2.height - 20), c2)
bg.convert("RGB").resize((256, 256), Image.LANCZOS).save(f"{BASE}/game/icon.png")
bg.convert("RGB").save(f"{FE}/icon_fixed_512.png")

# --- yellow sibling ---
redband = ((hue2 > 0.88) | (hue2 < 0.045)) & (sat2 > 0.25) & (val > 0.18)
h3 = np.where(redband, 0.118, hue2)
yr, yg, yb = hsv2rgb(h3, sat2, val)
yimg = Image.fromarray((np.clip(np.stack([yr, yg, yb, alpha], -1), 0, 1) * 255).astype(np.uint8))
yimg = yimg.crop(yimg.getbbox())
yimg.save(f"{BASE}/game/assets/sprites/boghi_yellow_side.png")
print("yellow:", yimg.size)

# --- review sheet ---
sheet = Image.new("RGB", (1240, 620), (225, 225, 225))
bb = car.copy(); bb.thumbnail((600, 570)); sheet.paste(bb, (15, 25), bb)
yb2 = yimg.copy(); yb2.thumbnail((600, 570)); sheet.paste(yb2, (625, 25), yb2)
icf = Image.open(f"{FE}/icon_fixed_512.png").resize((230, 230)); sheet.paste(icf, (995, 380))
sheet.save(f"{FE}/review_sheet3.png")
print("DONE")
