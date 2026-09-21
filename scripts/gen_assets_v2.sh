#!/bin/bash
# Generation N-2 for Boghi: semi-realistic painted style, saturated golden hour,
# REAL Iranian cars (Pride/Dena/Shahin/Tiba/206/Samand/Nissan/Quick) per user request.
# Magenta backgrounds for chroma-key pipeline (process_sprites_v2.py).
set -u
OUT=/home/z/my-project/scripts/sprites_raw_v2
mkdir -p "$OUT"

STYLE="hand-painted semi-realistic automotive concept art, glossy car paint with strong specular highlights, deep rich saturated colors, dramatic golden-hour rim lighting, realistic car proportions, low sporty stance, detailed alloy wheels with dark rubber tires, clean crisp edges, subtle painterly brush texture, cinematic contrast, high quality, no text, no letters, no watermark, no brand logos, no people, no ground shadow, no cast shadow on background"
MAG="entirely on a flat solid pure magenta background (#FF00FF),"

gen() { # $1=name $2=size $3=prompt
  local f="$OUT/$1.png"
  if [ -s "$f" ]; then echo "SKIP $1"; return 0; fi
  echo "GEN $1 ..."
  z-ai image -p "$3, $MAG $STYLE" -o "$f" -s "$2" || echo "FAIL $1"
}

case "${1:-all}" in
cars1)
  gen boghi_side 1024x1024 "a cheerful compact classic Iranian hatchback car similar to a tuned Saipa Pride, glossy deep teal turquoise paint, subtle friendly Pixar-style eyes integrated into the windshield glass (small expressive, not childish), golden star emblem on the hood, small rear spoiler, warm headlight glow"
  gen pride_side 1024x1024 "a red tuned Iranian compact hatchback race car similar to a tuned Saipa Pride, glossy candy apple red paint, large rear wing spoiler, white racing stripes over hood and roof, lowered sporty suspension, black front splitter"
  gen dena_side 1024x1024 "a modern Iranian mid-size sedan car similar to IKCO Dena Plus, glossy pearl white paint, chrome window trim, elegant sporty sedan silhouette, amber turn signal glow"
  gen shahin_side 1024x1024 "a modern Iranian sporty sedan car similar to Saipa Shahin, glossy deep black paint with a subtle red accent stripe along the doors, aggressive front bumper, dark gunmetal alloy wheels"
  gen tiba_side 1024x1024 "a small Iranian city hatchback car similar to Saipa Tiba, glossy vivid sky blue paint, compact nimble cheerful look, clean simple lines"
  ;;
cars2)
  gen pejo_side 1024x1024 "a French-style compact hatchback car similar to a Peugeot 206, glossy metallic silver paint, sleek agile curves, fog light glow"
  gen samand_side 1024x1024 "a classic Iranian family sedan car similar to IKCO Samand, glossy graphite gray metallic paint, dignified classic sedan proportions, warm interior glow through windows"
  gen nissan_side 1024x1024 "a compact Iranian pickup truck similar to a Nissan Z24 pickup, glossy bright red paint, small cargo bed with dark bed liner, rugged sturdy stance, roll bar over the bed"
  gen quick_side 1024x1024 "a small modern Iranian city hatchback car similar to a Saipa Quick, glossy vibrant orange paint, youthful sporty look, black roof spoiler and black side mirrors"
  ;;
env)
  gen bg_sky 1344x768 "dramatic golden hour sky seen from a city, deep saturated gradient from rich glowing orange and coral near the horizon to dark teal-blue at the top, low bright sun, bold purple and magenta clouds with burning golden edges, cinematic high contrast, no city, no buildings, sky only"
  gen bg_far 1344x768 "distant panoramic view of a big Iranian city skyline at golden hour, white grand arch monument with geometric lattice pattern near the center-left, tall slender tower with an octagonal observation pod near the center-right, snow-capped volcano mountain far behind, dense warm glowing city buildings stretching beyond both left and right edges, rich saturated amber and teal palette, cinematic depth, skyline does not touch the top edge"
  gen road_strip 1344x768 "a perfectly horizontal straight city asphalt road band crossing the middle of the frame seen exactly from the side, dark fresh asphalt with subtle grain texture, bright white dashed lane line, solid warm yellow edge lines, thin gray concrete curb along the top edge of the band, everything above and below the road band is flat solid pure magenta"
  gen menu_bg 1344x768 "golden hour view over a big Iranian city from a quiet park street, glossy teal compact hatchback with a golden star on the hood parked in the lower left foreground seen from three-quarter view, white arch monument and tall tower glowing in the warm distance, rich saturated sunset sky with bold clouds, inviting cinematic painterly mood"
  gen bg_mid 1344x768 "a horizontal band of city street trees, tall poplars and cypresses and leafy bushes, rich deep saturated greens with warm golden sun-kissed highlights, painted semi-realistic, everything above and below the tree band is flat solid pure magenta"
  ;;
items)
  gen coin 1024x1024 "a shiny embossed golden coin with a five-pointed star in the center, glossy dramatic lighting, front view filling the frame, thick clean edge"
  gen cone 1024x1024 "a bright orange traffic cone with two white reflective stripes, glossy plastic, front view"
  gen passenger 1024x1024 "a friendly young Iranian taxi passenger standing and waving one hand happily, painted semi-realistic storybook style, teal shirt and dark jeans, full body front view"
  gen ramp 1024x1024 "a sturdy wooden car jump ramp wedge with a steel frame and worn metal edge, warm brown wood planks, side view"
  ;;
*)
  echo "usage: $0 cars1|cars2|env|items"; exit 1;;
esac
echo "PART $1 DONE"
