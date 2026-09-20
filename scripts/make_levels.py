#!/usr/bin/env python3
"""Generate 50 levels for Season 1 (Tehran) — data-driven level design with difficulty curve."""
import json

types = ["race", "collect", "taxi", "race", "challenge"]

names = [
    "کوچه‌های محله", "بوق اول", "آموزش پرش", "دوچرخه‌سوارها", "پیک محله",
    "سکه‌های کوچه", "مسافر اول", "شیفت صبح", "رمپ گِلی", "چالش محله",
    "خیابان ولیعصر", "پارک ملت", "شلوغی عصر", "دوگانه‌سوزها", "سکه‌باران ولیعصر",
    "مسافرهای پارک", "چراغ‌راهنما", "شیفت دوپهلو", "رمپ‌های ملت", "چالش ولیعصر",
    "بزرگراه صبح", "پل طبیعت", "جاده سبز", "باد مخالف", "باران سبک",
    "سکه‌های پل", "مسافرهای بزرگراه", "کامیون‌ها", "رمپ دوتایی", "چالش بزرگراه",
    "بازار بزرگ", "توپخانه", "کوچه‌های بازار", "اسب‌ها و کالسکه", "شلوغی بازار",
    "سکه‌های بازار", "مسافرهای چانه‌زن", "شیفت بازار", "رمپ بارها", "چالش بازار",
    "دور برج میلاد ۱", "دور برج میلاد ۲", "ستاره‌های میلاد", "مسافران VIP", "طوفان میلاد",
    "دور برج میلاد ۳", "شب‌گردی میلاد", "مأموریت ستاره‌دار", "آخرین تمرین", "فینال: شاه‌راه!",
]

levels = []
for i in range(50):
    n = i + 1
    typ = types[i % 5] if n != 50 else "race"
    if n == 50:
        typ = "race"
    # difficulty curve 0..1
    d = i / 49
    speed = round(12 + 14 * d, 1)          # 12 -> 26
    distance = int(400 + 1400 * d)          # 400 -> 1800
    time_limit = int(distance / speed * 1.55 + 12 - 6 * d)
    obstacle_rate = round(0.45 + 0.55 * d, 2)
    coin_rate = round(0.95 - 0.25 * d, 2)
    ramp_rate = round(0.25 + 0.2 * d, 2)
    reward = 40 + n * 8
    lv = {
        "id": n,
        "type": typ,
        "name": names[i],
        "district": ("محله" if n <= 10 else "ولیعصر" if n <= 20 else
                     "بزرگراه" if n <= 30 else "بازار" if n <= 40 else "میلاد"),
        "speed": speed,
        "distance": distance,
        "time": time_limit,
        "obstacle_rate": obstacle_rate,
        "coin_rate": coin_rate,
        "ramp_rate": ramp_rate,
        "reward": reward,
    }
    if typ == "collect":
        lv["target_coins"] = int(10 + 20 * d)
    if typ == "taxi":
        lv["target_passengers"] = int(2 + 4 * d)
    if typ == "challenge":
        lv["target_coins"] = int(8 + 14 * d)
        lv["time"] = int(time_limit * 0.9)
    levels.append(lv)

season = {
    "season": 1,
    "city": "tehran",
    "city_name": "تهران",
    "levels": levels,
}
path = "/home/z/my-project/game/data/season1_tehran.json"
with open(path, "w", encoding="utf-8") as f:
    json.dump(season, f, ensure_ascii=False, indent=1)
print("levels:", len(levels))
print("sample L1:", json.dumps(levels[0], ensure_ascii=False))
print("sample L50:", json.dumps(levels[49], ensure_ascii=False))
