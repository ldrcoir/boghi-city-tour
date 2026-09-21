#!/bin/bash
# Generate painterly gouache assets for Boghi (clean-source pipeline, no third-party brands)
set -u
OUT=/home/z/my-project/scripts/sprites_raw
mkdir -p "$OUT"
STYLE="warm gouache childrens storybook illustration, soft rounded shapes, thick dark brown outlines, golden hour light, subtle cream paper texture, high quality, no text, no letters, no words"
MAG="entirely on a flat solid magenta background,"

gen() { # $1=name $2=size $3=prompt
  local f="$OUT/$1.png"
  if [ -s "$f" ]; then echo "SKIP $1 (exists)"; return 0; fi
  echo "GEN $1 ..."
  z-ai image -p "$3, $STYLE" -o "$f" -s "$2" || echo "FAIL $1"
}

case "${1:-all}" in
part1)
  gen bg_sky 1344x768 "peaceful golden sunset sky seen from a hilltop, big soft rounded cumulus clouds glowing warm cream and peach, gentle gradient from warm apricot near the horizon to soft teal blue at the top, two tiny distant birds"
  gen menu_bg 1344x768 "view from a flowered grassy hilltop over a fantasy city at golden sunset, in the lower left a cheerful teal cartoon car with big friendly eyes and a golden star on its hood parked among flowers, far below a grand white arch monument and a tall tower with an octagonal observation pod, upper half mostly open sunset sky with a few soft clouds, warm cream teal and gold palette"
  gen boghi_side 1024x1024 "cute small teal compact car in perfect side view facing right, big happy round eyes on the windshield, cheerful smiling front bumper, a golden star emblem on the hood, tiny flag antenna on the back, round puffy wheels with cream hubcaps, car does not touch image edges"
  gen sharare_side 1024x1024 "cute coral red sporty hatchback car in perfect side view facing right, confident eyebrows above round eyes on the windshield, cheeky grin, cream racing stripe on the hood, round puffy wheels with cream hubcaps, car does not touch image edges"
  gen zabib_side 1024x1024 "cute sky blue pickup truck with small cargo bed in perfect side view facing right, kind sleepy friendly eyes on the windshield, gentle warm smile, wooden crate in the truck bed, round puffy wheels with cream hubcaps, car does not touch image edges"
  ;;
part2)
  gen bg_far 1344x768 "distant fantasy city skyline at dusk, a grand white marble arch monument with geometric lattice pattern on the left, a tall slender tower with an octagonal observation pod near its top on the right, small cozy painted houses and domes between them, soft warm haze, skyline does not touch the top edge"
  gen bg_mid 1344x768 "rolling green grassy hills with tall poplar trees, round bushes, colorful tiny flowers and a small wooden signpost, soft rounded storybook shapes"
  gen road_strip 1344x768 "horizontal straight country road band across the middle of the frame, seen perfectly from the side, warm tan asphalt with a cream dashed center line, thin painted grass strip along the top and bottom edges of the road band, everything above and below the road band is flat solid magenta"
  gen plate_empty 1024x1024 "blank white car license plate with an ornate rounded golden metal frame decorated with small golden stars, completely empty plain white center"
  ;;
part3)
  gen coin 1024x1024 "cute shiny golden coin with a small star embossed in the center, thick dark brown outline, front view filling the frame"
  gen cone 1024x1024 "cute small orange traffic cone with a cream stripe and rounded corners, thick dark brown outline, front view"
  gen passenger 1024x1024 "cute happy little kid standing and waving with one hand, big round eyes, teal shirt, thick dark brown outline, front view, full body"
  gen ramp 1024x1024 "small wooden ramp wedge with a cream stripe and rounded corners, side view, thick dark brown outline"
  ;;
*)
  echo "usage: $0 part1|part2|part3"; exit 1;;
esac
echo "PART ${1:-all} DONE"
