#!/bin/bash
# Post-process APK: STORE every entry (no DEFLATE anywhere) -> removes any
# compressed-asset random-access issues on Android AssetManager, then
# zipalign + apksigner (debug keystore). Verifies structure before/after.
set -euo pipefail

IN="${1:?input apk}"
OUT="${2:?output apk}"
BT=/home/z/android-sdk/build-tools/34.0.0
KS=/home/z/.android/debug.keystore
TMP=/home/z/my-project/build/apkpp_work

echo "== BEFORE: entries=$(unzip -l "$IN" | tail -1 | awk '{print $2}')  deflate=$(unzip -v "$IN" | grep -c 'Defl' || true)"

rm -rf "$TMP" "$OUT" "$OUT.aligned"
python3 /home/z/my-project/scripts/rezip_assets_stored.py "$IN" "$OUT"

# page-align shared libs + 4-byte align everything
"$BT/zipalign" -f -p 4 "$OUT" "$OUT.aligned"
mv "$OUT.aligned" "$OUT"

# sign (v1+v2+v3 as applicable)
"$BT/apksigner" sign --ks "$KS" --ks-key-alias androiddebugkey \
        --ks-pass pass:android --key-pass pass:android "$OUT"
"$BT/apksigner" verify "$OUT"

echo "== AFTER: entries=$(unzip -l "$OUT" | tail -1 | awk '{print $2')}  deflate=$(unzip -v "$OUT" | grep -c 'Defl' || true)"
echo "== badging:"
"$BT/aapt2" dump badging "$OUT" | grep -E "^package|native-code|sdkVersion|application-label:" | head -6
echo "SIZE: $(stat -c%s "$OUT")"
sha256sum "$OUT"
rm -rf "$TMP"
