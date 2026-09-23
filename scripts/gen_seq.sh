#!/bin/bash
# تولید سکوئنشیال اسپرایت‌های v1.0 — با skip-if-exists و retry
# استفاده: gen_seq.sh <بچ‌نام>
set -u
OUT=/home/z/my-project/scripts/car_gen
mkdir -p "$OUT"

RS='3D animated movie style serious race car, chunky rounded toy-like proportions, oversized glossy body, completely clean bodywork with absolutely no eyes and no face and no cartoon features, dark tinted black racing windshield with a subtle silhouette of a helmeted race driver inside, glossy metallic car paint with soft studio reflections and rim light, three-quarter front view showing front and side, car facing to the right, wheels perfectly straight, entire car centered fully visible with generous margin, isolated on a solid flat pure magenta background, no ground, no shadow, no text, no license plate, no brand logos, no watermark, high quality detailed render'

F1='3D animated movie style cute living formula one race car character, chunky rounded toy-like proportions, open-wheel formula racing car with four big rounded exposed wheels, large front wing and tall rear wing, low slung body, big expressive cartoon eyes on the white helmet in the open cockpit, friendly smiling mouth on the front nose cone, glossy metallic paint with soft studio reflections and rim light, three-quarter front view showing front and side, car facing to the right, wheels perfectly straight, entire car centered fully visible with generous margin, isolated on a solid flat pure magenta background, no ground, no shadow, no text, no license plate, no brand logos, no watermark, high quality detailed render'

F1R='3D animated movie style serious formula one race car, chunky rounded toy-like proportions, open-wheel formula racing car with four big rounded exposed wheels, large front wing and tall rear wing, low slung body, completely clean bodywork with absolutely no eyes and no face, open cockpit with a subtle silhouette of a helmeted race driver inside, glossy metallic paint with soft studio reflections and rim light, three-quarter front view showing front and side, car facing to the right, wheels perfectly straight, entire car centered fully visible with generous margin, isolated on a solid flat pure magenta background, no ground, no shadow, no text, no license plate, no brand logos, no watermark, high quality detailed render'

gen() { # $1=name $2=prompt
  if [ -s "$OUT/$1.png" ]; then echo "skip $1"; return 0; fi
  for try in 1 2 3; do
    echo "== $1 (try $try) =="
    if z-ai image -p "$2" -o "$OUT/$1.png" -s 1024x1024; then return 0; fi
    sleep 12
  done
  echo "FAIL $1"
}

case "${1:-a}" in
a)
  gen "race_boghi_yellow" "$RS, sunny yellow small hatchback car, tiny spoiler"
  gen "race_tiba" "$RS, light sky blue compact sedan car"
  gen "race_pride" "$RS, red racing hatchback car with white racing stripes on hood and big rear wing"
  gen "race_pejo" "$RS, silver metallic compact hatchback car"
  gen "race_samand" "$RS, cream beige classic sedan car with chrome grille"
  ;;
b)
  gen "race_dena" "$RS, pearl white modern sedan car with chrome details"
  gen "race_nissan" "$RS, red vintage pickup truck with chunky big fenders"
  gen "race_pejo_race" "$RS, fire red sport hatchback car with bold white rally stripes and large black rear wing"
  gen "race_shahin" "$RS, sleek black sport sedan car with thin gold stripe along the side"
  gen "race_quick" "$RS, bright orange small hatchback car"
  ;;
c)
  gen "race_dena_race" "$RS, white racing sedan car with red accents and low front splitter"
  gen "race_pride_blue" "$RS, ocean blue racing hatchback car with white racing stripes and big rear wing"
  gen "race_pejo_green" "$RS, emerald green racing hatchback car with black racing stripes and rear wing"
  gen "race_shahin_white" "$RS, pearl white racing sport sedan car with gold racing stripes and carbon front splitter"
  gen "race_dena_red" "$RS, candy red racing sedan car with white racing roundel stripes and low spoiler"
  ;;
d)
  gen "nissan_blue" "$RS changes: cute living car character with big expressive cartoon eyes and friendly smile instead of the serious mode. 3D animated movie style cute living car character, chunky rounded toy-like proportions, vintage pickup truck with chunky big fenders, deep blue metallic paint, thick friendly eyebrows above windshield eyes, hearty warm confident smile, glossy paint, three-quarter front view, car facing to the right, isolated on solid flat pure magenta background, no ground, no shadow, no text, high quality detailed render"
  gen "formula_red" "$F1, candy apple red formula one car with white wing tips, fearless champion personality"
  gen "formula_black" "$F1, glossy black formula one car with thin gold stripes and gold wing tips, cool night racer personality"
  gen "formula_blue" "$F1, ocean blue formula one car with white accents and blue wing tips, cheerful rookie personality"
  ;;
e)
  gen "race_formula_red" "$F1R, candy apple red formula one car with white wing tips"
  gen "race_formula_black" "$F1R, glossy black formula one car with thin gold stripes and gold wing tips"
  gen "race_formula_blue" "$F1R, ocean blue formula one car with white accents and blue wing tips"
  gen "race_nissan_blue" "$RS, deep blue metallic vintage pickup truck with chunky big fenders"
  gen "akbar" '3D animated movie style cartoon character, young Iranian street racer man, thick black mustache, long striped jersey scarf loosely wrapped around his neck, short black hair, confident smug playful grin, arms crossed, classic plain white t-shirt, dark trousers and old sneakers, standing pose leaning back casually, full body from head to shoes, whole character fully visible with generous margin, isolated on a solid flat pure magenta background, no ground, no shadow, no text, no brand logos, no watermark, high quality detailed render'
  ;;
esac
echo "BATCH ${1:-a} DONE: $(ls $OUT/*.png 2>/dev/null | wc -l) files"
