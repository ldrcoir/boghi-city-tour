#!/bin/bash
# Generation N-3 for Boghi: glossy painted ENVIRONMENT to match the beloved car style.
# User feedback: Tehran map "soulless and pale" — road was grey photo asphalt,
# skyline was a washed-out photo. N-3 = saturated golden-hour painted game art.
# Magenta backgrounds for chroma-key pipeline (process_sprites_v3.py).
set -u
OUT=/home/z/my-project/scripts/sprites_raw_v3
mkdir -p "$OUT"

STYLE="painted semi-realistic cinematic game art, glossy surfaces with strong specular highlights, deep rich saturated colors, dramatic golden-hour rim lighting, hand-painted look with subtle brush texture, cinematic contrast, high quality, no text, no letters, no watermark, no brand logos, no people, no cars"
MAG="entirely on a flat solid pure magenta background (#FF00FF),"

gen() { # $1=name $2=size $3=prompt
  local f="$OUT/$1.png"
  if [ -s "$f" ]; then echo "SKIP $1"; return 0; fi
  for try in 1 2 3 4; do
    echo "GEN $1 (try $try) ..."
    if z-ai image -p "$3, $STYLE" -o "$f" -s "$2"; then return 0; fi
    sleep 25
  done
  echo "FAIL $1"
}

case "${1:-all}" in
sky)
  # Full painted sky — replaces dead dark backdrop
  gen bg_sky 1344x768 "dramatic golden hour sky over a big city, deep saturated gradient from glowing orange and coral near the horizon to rich indigo and teal at the top, huge warm sun glow low near the horizon, bold stylized clouds with burning golden edges and soft violet undersides, a few birds far away"
  ;;
far)
  # Tehran skyline PAINTED (not photo!) — Azadi + Milad + snowy Alborz
  gen bg_far 1344x768 "panoramic painted view of a grand Iranian capital city skyline at golden hour, big white marble arch monument like Azadi Tower with geometric lattice pattern near center-left, tall slender white tower with octagonal observation pod near center-right, snow-capped mountains glowing pink and gold behind the city, dense warm city with tiny glowing windows stretching to both edges, rich saturated amber orange and deep teal palette, skyline occupying the lower half of the frame"
  ;;
mid)
  # Colorful street buildings band (chroma-keyed) — replaces plain trees
  gen bg_mid 1344x768 "a horizontal band of colorful Iranian city street buildings and small shops with striped awnings, arched windows, balconies, air conditioners and leafy green trees between buildings, turquoise brick and saffron and cream colored facades with warm glowing windows, low brick wall at the bottom, everything above and below the building band is flat solid pure magenta (#FF00FF)"
  ;;
road)
  # Glossy warm road band (chroma-keyed) — replaces grey photo asphalt
  gen road_strip 1344x768 "a perfectly horizontal straight city asphalt road band crossing the middle of the frame seen exactly from the side, warm dark charcoal asphalt with glossy golden-hour sheen and subtle grain, crisp bright white dashed lane line across the band, solid saturated warm yellow edge lines at the top and bottom of the band, narrow strip of red brick paved sidewalk with a thin concrete curb along the top edge, everything above and below the road band is flat solid pure magenta (#FF00FF)"
  ;;
menu)
  gen menu_bg 1344x768 "golden hour view over a colorful Iranian capital city street from a quiet park, white marble arch monument and tall white tower glowing warm in the distance, rich saturated orange and pink sunset sky with bold golden clouds, string lights and lush green trees framing the view, empty cozy street, inviting cinematic mood"
  ;;
garage)
  # Ustad Faner workshop interior
  gen garage_bg 1344x768 "cozy warm Iranian car repair workshop interior at evening, open rolling shutter door revealing an orange sunset street with a white arch monument far away, tool boards with wrenches and hammers, stacks of new tires, a red tool chest, hanging work lamps with warm glowing light, glossy floor reflecting the sunset light, rich saturated colors, clean organized space"
  gen ustad 1024x1024 "cheerful chubby middle-aged Iranian car mechanic master with a big proud curled black mustache, wearing a teal blue jumpsuit and a red flat cap, holding a shiny silver wrench in one raised hand, warm friendly confident smile, full body standing front view, painted storybook game character art, thick clean edges"
  ;;
*)
  echo "usage: $0 sky|far|mid|road|menu|garage"; exit 1;;
esac
echo "PART $1 DONE"
