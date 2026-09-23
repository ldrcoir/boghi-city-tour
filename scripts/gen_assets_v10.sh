#!/bin/bash
# تولید ۳ asset جدید v1.0 — همه باید با سیستم بینایی تست شوند قبل از ورود به بازی!
set -u
OUT=/home/z/my-project/scripts/car_gen
mkdir -p "$OUT"

# ۱) بک‌گراند منو — خیابان خالی تهران هنگام غروب، بدون هیچ ماشین و متن و UI
BG='2D flat vector painted illustration for a racing game menu, Tehran cityscape at warm dramatic dusk, Azadi tower in the middle distance, Milad tower far left silhouette, orange and purple sunset sky with soft clouds, wide empty asphalt street in the foreground sweeping from left with red and white curbs, glowing street lamps, green trees along the sidewalk, NO cars on the road, NO people, NO text, NO letters, NO logos, NO ui elements, clean empty road, cinematic warm lighting, high quality'
z-ai image -p "$BG" -o "$OUT/menu_bg_raw.png" -s 1472x736 || echo "FAIL menu_bg"

# ۲) پلاک مسابقه‌ای نوجوان‌پسند — بدون هیچ آدم و بچه! متال تیره + نئون طلایی
PLATE='3D animated movie style blank racing license plate prop, dark gunmetal carbon fiber plate with glowing neon golden rim, chunky rounded corners, two shiny silver bolts on left and right sides, empty flat center area reserved for a name, glossy studio render, isolated on a solid flat pure magenta background, no text, no letters, no numbers, no people, no faces, no watermark, high quality'
z-ai image -p "$PLATE" -o "$OUT/plate_raw.png" -s 1024x1024 || echo "FAIL plate"

# ۳) اکبر سیبیلو — شخصیت طنز کوچه: سیبیلو با لونگ سفید دور گردن
AKBAR='3D animated movie style funny young Iranian street character, young man with big thick black mustache, long white keffiyeh scarf loosely wrapped around his neck, open dark jacket over striped t-shirt, one hand giving thumbs up, confident playful smirk, slightly chunky stylized proportions matching cute animated car movie style, waist-up three-quarter view facing right, glossy pixar-like render, isolated on a solid flat pure magenta background, no text, no watermark, high quality'
z-ai image -p "$AKBAR" -o "$OUT/akbar_raw.png" -s 1024x1024 || echo "FAIL akbar"

echo ALL_DONE
ls -la "$OUT" | grep raw
