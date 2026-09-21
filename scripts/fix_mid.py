#!/usr/bin/env python3
"""Re-trim bg_mid tree band: drop rows/cols without meaningful content."""
import numpy as np, cv2
from PIL import Image, ImageFilter

RAW = "/home/z/my-project/scripts/sprites_raw_v2/bg_mid.png"
OUT = "/home/z/my-project/game/assets/sprites/bg_mid.png"

rgb = np.array(Image.open(RAW).convert("RGB"))
r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
mag = (r > g + 40) & (b > g + 15)
alpha = np.where(mag, 0, 255).astype(np.uint8)
# keep only rows/cols with real content
rows = np.where((alpha > 128).mean(axis=1) > 0.03)[0]
cols = np.where((alpha > 128).mean(axis=0) > 0.03)[0]
top, bot = int(rows.min()), int(rows.max()) + 1
left, right = int(cols.min()), int(cols.max()) + 1
a = cv2.GaussianBlur(alpha, (5, 5), 1.0)[top:bot, left:right]
rgba = np.dstack([rgb[top:bot, left:right], a])
img = Image.fromarray(rgba).filter(ImageFilter.SMOOTH)
img.save(OUT)
print("bg_mid re-trimmed ->", img.size)
