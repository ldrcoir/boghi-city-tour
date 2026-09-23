#!/bin/bash
# نسخه ۱٫۰ — تولید دو پیکربندی برای هر ماشین:
#  ۱) race_: چهره جدی بدون چشم برای داخل مسابقه (کاکپیت تیره با هلمت راننده)
#  ۲) cute: فرمول‌یک‌ها + نیسان آبی اکبر با چشم (برای منو/گاراژ/جشن بعد خط پایان)
#  ۳) akbar: پرتره کاراکتر اکبر سیبیلو
# خروجی خام → scripts/car_gen/  (gitignored)
set -u
OUT=/home/z/my-project/scripts/car_gen
mkdir -p "$OUT"

# بایبل چهره جدی — همان بدن چاق-براق ولی بدون صورت، شیشه دودی با سیلوئت کلاه
RACE_STYLE='3D animated movie style serious race car, chunky rounded toy-like proportions, oversized glossy body, completely clean bodywork with absolutely no eyes and no face and no cartoon features, dark tinted black racing windshield with a subtle silhouette of a helmeted race driver inside, glossy metallic car paint with soft studio reflections and rim light, three-quarter front view showing front and side, car facing to the right, wheels perfectly straight, entire car centered fully visible with generous margin, isolated on a solid flat pure magenta background, no ground, no shadow, no text, no license plate, no brand logos, no watermark, high quality detailed render'

# بدنه‌ها — رنگ و مدل دقیقاً همتای نسخه چشم‌دار تا تعویض در جشن بی‌نقص دیده شود
declare -A BODIES
BODIES[boghi]='candy apple red small hatchback car, tiny red rear spoiler'
BODIES[boghi_yellow]='sunny yellow small hatchback car, tiny spoiler'
BODIES[tiba]='light sky blue compact sedan car'
BODIES[pride]='red racing hatchback car with white racing stripes on hood and big rear wing'
BODIES[pejo]='silver metallic compact hatchback car'
BODIES[samand]='cream beige classic sedan car, chrome grille'
BODIES[dena]='pearl white modern sedan car, chrome details'
BODIES[nissan]='red vintage pickup truck with chunky big fenders'
BODIES[pejo_race]='fire red sport hatchback car with bold white rally stripes and large black rear wing'
BODIES[shahin]='sleek black sport sedan car with thin gold stripe along the side'
BODIES[quick]='bright orange small hatchback car'
BODIES[dena_race]='white racing sedan car with red accents and low front splitter'
BODIES[pride_blue]='ocean blue racing hatchback car with white racing stripes and big rear wing'
BODIES[pejo_green]='emerald green racing hatchback car with black racing stripes and rear wing'
BODIES[shahin_white]='pearl white racing sport sedan car with gold racing stripes and carbon front splitter'
BODIES[dena_red]='candy red racing sedan car with white racing roundel stripes and low spoiler'

F1_STYLE='3D animated movie style cute living formula one race car character, chunky rounded toy-like proportions, open-wheel formula racing car with four big rounded exposed wheels, large front wing and tall rear wing, low slung body, big expressive cartoon eyes on the white helmet in the open cockpit, friendly smiling mouth on the front nose cone, glossy metallic paint with soft studio reflections and rim light, three-quarter front view showing front and side, car facing to the right, wheels perfectly straight, entire car centered fully visible with generous margin, isolated on a solid flat pure magenta background, no ground, no shadow, no text, no license plate, no brand logos, no watermark, high quality detailed render'

F1_RACE_STYLE='3D animated movie style serious formula one race car, chunky rounded toy-like proportions, open-wheel formula racing car with four big rounded exposed wheels, large front wing and tall rear wing, low slung body, completely clean bodywork with absolutely no eyes and no face, open cockpit with a subtle silhouette of a helmeted race driver inside, glossy metallic paint with soft studio reflections and rim light, three-quarter front view showing front and side, car facing to the right, wheels perfectly straight, entire car centered fully visible with generous margin, isolated on a solid flat pure magenta background, no ground, no shadow, no text, no license plate, no brand logos, no watermark, high quality detailed render'

gen() { # $1=name $2=prompt
  if [ -s "$OUT/$1.png" ]; then echo "skip $1"; return; fi
  echo "== $1 =="
  z-ai image -p "$2" -o "$OUT/$1.png" -s 1024x1024 || echo "FAIL $1"
}

ONLY="${1:-all}"

if [ "$ONLY" = "all" ] || [ "$ONLY" = "race" ]; then
  for id in "${!BODIES[@]}"; do
    gen "race_$id" "$RACE_STYLE, ${BODIES[$id]}"
  done
fi

if [ "$ONLY" = "all" ] || [ "$ONLY" = "extra" ]; then
  # فرمول‌یک‌های بوقی — سه تیم
  gen "formula_red"  "$F1_STYLE, candy apple red formula one car with white wing tips, fearless champion personality"
  gen "formula_black" "$F1_STYLE, glossy black formula one car with thin gold stripes and gold wing tips, cool night racer personality"
  gen "formula_blue" "$F1_STYLE, ocean blue formula one car with white accents and blue wing tips, cheerful rookie personality"
  gen "race_formula_red"   "$F1_RACE_STYLE, candy apple red formula one car with white wing tips"
  gen "race_formula_black" "$F1_RACE_STYLE, glossy black formula one car with thin gold stripes and gold wing tips"
  gen "race_formula_blue"  "$F1_RACE_STYLE, ocean blue formula one car with white accents and blue wing tips"
  # نیسان آبی اکبر سیبیلو — چشم‌دار و جدی
  gen "nissan_blue" '3D animated movie style cute living car character, chunky rounded toy-like proportions, vintage pickup truck with chunky big fenders, deep blue metallic paint, thick friendly eyebrows above windshield eyes, hearty warm confident smile, glossy paint with soft studio reflections and rim light, three-quarter front view showing front and side, car facing to the right, wheels perfectly straight, entire car centered fully visible with generous margin, isolated on a solid flat pure magenta background, no ground, no shadow, no text, no license plate, no brand logos, no watermark, high quality detailed render'
  gen "race_nissan_blue" "$RACE_STYLE, deep blue metallic vintage pickup truck with chunky big fenders"
  # پرتره اکبر سیبیلو — کاراکتر انسانی
  gen "akbar" '3D animated movie style cartoon character, young Iranian street racer man, thick black mustache, long striped jersey scarf loosely wrapped around his neck, short black hair, confident smug playful grin, arms crossed, classic plain white t-shirt, dark trousers and old sneakers, standing pose leaning back casually, full body from head to shoes, whole character fully visible with generous margin, isolated on a solid flat pure magenta background, no ground, no shadow, no text, no brand logos, no watermark, high quality detailed render'
fi

echo DONE
ls "$OUT" | wc -l
