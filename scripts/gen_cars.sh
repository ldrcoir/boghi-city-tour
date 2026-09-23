#!/bin/bash
# تولید ۱۲ اسپرایت ماشین «بوقی» به سبک چاق-براق رفرنس‌های کاربر (hero_car_A/B)
# پس‌زمینه ماژنتا تخت برای حذف تمیز در make_car_sprites.py
set -u
OUT=/home/z/my-project/scripts/car_gen
mkdir -p "$OUT"

STYLE='3D animated movie style cute living car character, chunky rounded toy-like proportions, oversized glossy body, big expressive cartoon eyes with white sclera and large pupils on the windshield, friendly smiling mouth on the front bumper, glossy metallic car paint with soft studio reflections and rim light, cute original character design inspired by animated car movies, three-quarter front view showing front and side, car facing to the right, wheels perfectly straight, entire car centered fully visible with generous margin, isolated on a solid flat pure magenta background, no ground, no shadow, no text, no license plate, no brand logos, no watermark, high quality detailed render'

declare -A CARS
CARS[boghi]='candy apple red small hatchback car character, big cheerful smile showing white teeth, sparkling happy blue eyes, tiny red rear spoiler, lovable neighborhood hero'
CARS[boghi_yellow]='sunny yellow small hatchback car character, same smiling face, warm golden eyes, tiny spoiler, cheerful sunshine personality'
CARS[tiba]='light sky blue compact sedan car character, agile look, bright green eyes, playful grin'
CARS[pride]='red racing hatchback car character with white racing stripes on hood and big rear wing, determined happy smile, amber eyes, sporty stance'
CARS[pejo]='silver metallic compact hatchback car character, hazel eyes, confident friendly grin, clean modern look'
CARS[samand]='cream beige classic sedan car character, kind wise droopy eyes, gentle grandfather smile, chrome grille, trustworthy veteran look'
CARS[dena]='pearl white modern sedan car character, calm blue eyes, gentle smile, chrome details, elegant national sedan look'
CARS[nissan]='red vintage pickup truck character with chunky big fenders, thick friendly eyebrows above windshield eyes, hearty warm smile, tough burly body'
CARS[pejo_race]='fire red sport hatchback car character with bold white rally stripes and large black rear wing, excited wide eyes, big thrilled smile'
CARS[shahin]='sleek black sport sedan car character with thin gold stripe along the side, cool confident half-smile, sharp silver-grey eyes, mysterious night racer look'
CARS[quick]='bright orange small hatchback car character, huge excited eyes, hyper energetic open smile, bouncy youthful personality'
CARS[dena_race]='white racing sedan car character with red accents and low front splitter, focused happy smile, blue eyes, motorsport look'
CARS[pride_blue]='ocean blue racing hatchback car character with white racing stripes and big rear wing, excited happy smile, light blue eyes, sporty stance'
CARS[pejo_green]='emerald green racing hatchback car character with black racing stripes and rear wing, cheerful grin, hazel eyes, muscular fenders'
CARS[shahin_white]='pearl white racing sport sedan car character with gold racing stripes and carbon front splitter, confident smirk, sharp blue eyes, night racer turned champion look'
CARS[dena_red]='candy red racing sedan car character with white number-roundel style stripes and low spoiler, determined happy smile, amber eyes, champion motorsport look'

ONLY="${1:-all}"
for id in "${!CARS[@]}"; do
  if [ "$ONLY" != "all" ] && [ "$ONLY" != "$id" ]; then continue; fi
  if [ -s "$OUT/$id.png" ]; then echo "skip $id (exists)"; continue; fi
  echo "== generating $id =="
  z-ai image -p "$STYLE, ${CARS[$id]}" -o "$OUT/$id.png" -s 1024x1024 || echo "FAIL $id"
done
echo DONE
ls -la "$OUT"
