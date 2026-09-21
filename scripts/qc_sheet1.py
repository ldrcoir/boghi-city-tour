#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""برگه QC: مقایسه سر استاد قبل/بعد + ماشین‌های مسابقه‌ای قرمز جدید"""
from PIL import Image, ImageDraw, ImageFont

S = "/home/z/my-project/scripts"
A = "/home/z/my-project/game/assets/sprites"

orig = Image.open(f"{S}/ustad_backup_v1.png").convert("RGBA")
raw = Image.open(f"{S}/ustad_edit_raw.png").convert("RGBA")
W, H = orig.size
print("ustad original:", orig.size)
raw = raw.resize((W, H), Image.LANCZOS)

# بُرش ناحیه سر (بالا-وسط) برای مقایسه
hx0, hy0, hx1, hy1 = int(W*0.25), 0, int(W*0.80), int(H*0.62)
head_o = orig.crop((hx0, hy0, hx1, hy1))
head_e = raw.crop((hx0, hy0, hx1, hy1))

dena = Image.open(f"{A}/dena_race_side.png").convert("RGBA")
pejo = Image.open(f"{A}/pejo_race_side.png").convert("RGBA")

# بوم خاکستری روشن (آلفای خودروها/استاد دیده شود)
cell_w = max(head_o.width, head_e.width, dena.width, pejo.width) + 20
row1_h = head_o.height + 30
row2_h = max(dena.height, pejo.height) + 30
sheet = Image.new("RGB", (cell_w*2, row1_h + row2_h), (225, 225, 222))
sheet.paste(head_o, (10, 10), head_o)
sheet.paste(head_e, (cell_w + 10, 10), head_e)
sheet.paste(dena, (10, row1_h + 10), dena)
sheet.paste(pejo, (cell_w + 10, row1_h + 10), pejo)
d = ImageDraw.Draw(sheet)
d.text((10, 2), "BEFORE", fill=(0,0,0))
d.text((cell_w+10, 2), "AFTER (AI edit raw)", fill=(0,0,0))
d.text((10, row1_h+2), "dena_race", fill=(0,0,0))
d.text((cell_w+10, row1_h+2), "pejo_race", fill=(0,0,0))
sheet.save(f"{S}/qc_sheet1.png")
print("saved qc_sheet1.png", sheet.size)
