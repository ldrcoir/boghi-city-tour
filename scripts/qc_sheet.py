#!/usr/bin/env python3
"""Contact sheet of raw v2 assets for QC."""
import os, math
from PIL import Image, ImageDraw

RAW = "/home/z/my-project/scripts/sprites_raw_v2"
files = sorted(f for f in os.listdir(RAW) if f.endswith(".png"))
cols = 5
cell = 300
rows = math.ceil(len(files) / cols)
sheet = Image.new("RGB", (cols * cell, rows * (cell + 26)), (24, 24, 28))
dr = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    img = Image.open(os.path.join(RAW, f)).convert("RGB")
    img.thumbnail((cell - 10, cell - 10))
    x = (i % cols) * cell
    y = (i // cols) * (cell + 26)
    sheet.paste(img, (x + (cell - img.width) // 2, y + (cell - img.height) // 2))
    dr.text((x + 8, y + cell + 4), f, fill=(240, 240, 240))
sheet.save("/home/z/my-project/scripts/qc_sheet_v2.jpg", quality=88)
print("saved", sheet.size, len(files), "files")
