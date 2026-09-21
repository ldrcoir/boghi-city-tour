#!/usr/bin/env python3
"""Replace CARS roster in globals.gd with real Iranian car names (tabs preserved)."""
import re

P = "/home/z/my-project/game/scripts/globals.gd"
src = open(P, encoding="utf-8").read()

new_block = """# رشته ماشین‌ها: نام‌های واقعی و آشنای خیابان‌های ایران (درخواست کاربر)
# ترتیب = نردبان قیمت؛ پراید/تیبا/پژو/سمند/دنا/نیسان/شاهین/کوییک
const CARS := [
\t{
\t\t"id": "boghi", "name": "بوقی", "en": "Boghi",
\t\t"desc": "پراید فیروزه‌ای معروف محله — ستاره روی جلوپنجره!",
\t\t"tex": "res://assets/sprites/boghi_side.png",
\t\t"jump": 1.0, "accel": 1.0, "tough": 1.0, "price": 0
\t},
\t{
\t\t"id": "tiba", "name": "تیبا", "en": "Tiba",
\t\t"desc": "آبی و چابک — سبک برای پرش‌های دقیق",
\t\t"tex": "res://assets/sprites/tiba_side.png",
\t\t"jump": 1.12, "accel": 0.95, "tough": 0.8, "price": 600
\t},
\t{
\t\t"id": "pride", "name": "پراید قرمز", "en": "Pride RS",
\t\t"desc": "هاچ‌بک مسابقه‌ای با استریک و اسپویلر — شتاب بالا!",
\t\t"tex": "res://assets/sprites/pride_side.png",
\t\t"jump": 0.9, "accel": 1.18, "tough": 0.9, "price": 900
\t},
\t{
\t\t"id": "pejo", "name": "پژو ۲۰۶", "en": "Peugeot 206",
\t\t"desc": "نقره‌ای فرمان‌رو — تعادل عالی سرعت و کنترل",
\t\t"tex": "res://assets/sprites/pejo_side.png",
\t\t"jump": 1.0, "accel": 1.1, "tough": 0.95, "price": 1200
\t},
\t{
\t\t"id": "samand", "name": "سمند کلاسیک", "en": "Samand Classic",
\t\t"desc": "سالخورده‌ی مطمئن محله — مثل دیوار محکم",
\t\t"tex": "res://assets/sprites/samand_side.png",
\t\t"jump": 0.95, "accel": 0.9, "tough": 1.35, "price": 1500
\t},
\t{
\t\t"id": "dena", "name": "دنا پلاس", "en": "Dena Plus",
\t\t"desc": "سدان سفید ملی — شکوه و آرامش جاده",
\t\t"tex": "res://assets/sprites/dena_side.png",
\t\t"jump": 1.0, "accel": 1.15, "tough": 1.1, "price": 1800
\t},
\t{
\t\t"id": "nissan", "name": "نیسان قرمز", "en": "Nissan Pickup",
\t\t"desc": "وانت افسانه‌ای آسفالت‌خور — سنگین ولی شکست‌ناپذیر",
\t\t"tex": "res://assets/sprites/nissan_side.png",
\t\t"jump": 0.8, "accel": 0.85, "tough": 1.5, "price": 2200
\t},
\t{
\t\t"id": "shahin", "name": "شاهین", "en": "Shahin",
\t\t"desc": "مشکی اسپرت با خط طلایی — شاه شب‌های تهران",
\t\t"tex": "res://assets/sprites/shahin_side.png",
\t\t"jump": 0.9, "accel": 1.3, "tough": 1.0, "price": 2600
\t},
\t{
\t\t"id": "quick", "name": "کوییک", "en": "Quick",
\t\t"desc": "نارنجی جیغ جوان — پرش‌های بلند هوایی",
\t\t"tex": "res://assets/sprites/quick_side.png",
\t\t"jump": 1.25, "accel": 1.05, "tough": 0.75, "price": 3400
\t},
]"""

pat = re.compile(r"const CARS := \[.*?\n\]", re.S)
assert pat.search(src), "CARS block not found"
src = pat.sub(lambda m: new_block, src, count=1)
open(P, "w", encoding="utf-8").write(src)
print("CARS roster replaced OK")
