#!/bin/bash
# Fix pass: env/item assets that got cars baked in (STYLE had "automotive" wording).
set -u
OUT=/home/z/my-project/scripts/sprites_raw_v2
STYLE="hand-painted semi-realistic digital painting, deep rich saturated colors, golden-hour light, cinematic contrast, clean crisp edges, subtle painterly brush texture, high quality, no text, no letters, no watermark, empty scene with absolutely zero vehicles and zero cars anywhere"

gen() {
  local f="$OUT/$1.png"
  rm -f "$f"
  echo "GEN $1 ..."
  z-ai image -p "$3, $STYLE" -o "$f" -s "$2" || echo "FAIL $1"
}

gen bg_sky 1344x768 "a dramatic cloudscape at golden hour seen from high above a city, deep saturated gradient from glowing orange and coral near the bottom horizon to dark teal-blue at the top, low bright sun, bold purple and magenta clouds with burning golden edges, pure empty sky with clouds only"
gen bg_far 1344x768 "a distant panoramic city skyline viewed from far away at golden hour, white grand arch monument with geometric lattice pattern near the center-left, tall slender tower with an octagonal observation pod near the center-right, snow-capped volcano mountain far behind, dense warm glowing city buildings stretching beyond both left and right edges, rich amber and teal palette, the skyline is the only subject"
gen road_strip 1344x768 "a completely empty horizontal asphalt road band crossing the middle of the frame seen exactly from the side, dark fresh asphalt with subtle grain, bright white dashed lane line, solid warm yellow edge lines, thin gray concrete curb along the top edge of the band, nothing on the road, everything above and below the road band is flat solid pure magenta (#FF00FF)"
gen bg_mid 1344x768 "a horizontal band of dense street trees, tall poplars and cypresses and leafy bushes, rich deep saturated greens with warm golden sun-kissed highlights, only trees and bushes in the band, everything above and below the tree band is flat solid pure magenta (#FF00FF)"
gen passenger 1024x1024 "a friendly young Iranian man standing centered and waving one hand happily, painted semi-realistic storybook style, teal shirt and dark jeans, full body front view, single character only standing alone on a flat solid pure magenta background (#FF00FF)"
gen ramp 1024x1024 "an empty sturdy wooden car jump ramp wedge with a steel frame and worn metal edge, warm brown wood planks, side view, nothing on the ramp, flat solid pure magenta background (#FF00FF)"

echo "FIX DONE"
