#!/bin/bash
# Ship v0.7: create release, upload new APK (2 names), then replace EVERY old
# release's APK assets with the SAME v0.7 bytes under the SAME old names —
# so any link the user ever received now serves the fixed build.
set -euo pipefail
# توکن از فایل gitignore-شده خوانده می‌شود — هرگز داخل ریپو کامیت نشود
source /home/z/my-project/.secrets.env
PAT="${PAT:?set PAT in /home/z/my-project/.secrets.env}"
API="https://api.github.com/repos/ldrcoir/boghi-city-tour"
UP="https://uploads.github.com/repos/ldrcoir/boghi-city-tour"
APK=/home/z/my-project/download/BoghiCityTour_v0.7.apk

auth() { curl -s -H "Authorization: Bearer $PAT" "$@"; }

upload_asset() { # release_id  asset_name
        local rid="$1" name="$2" i rc
        for i in 1 2 3; do
                rc=0
                curl -s -o /tmp/up.json -w "%{http_code}" \
                        -H "Authorization: Bearer $PAT" \
                        -H "Content-Type: application/octet-stream" \
                        --data-binary @"$APK" \
                        "$UP/releases/$rid/assets?name=$name" > /tmp/up.code || rc=1
                local code; code=$(cat /tmp/up.code)
                if [ "$code" = "201" ]; then
                        echo "  uploaded $name -> release $rid (201)"
                        return 0
                fi
                echo "  retry $i: $name got $code $(head -c 200 /tmp/up.json)"
                sleep 5
        done
        return 1
}

delete_asset() { # asset_id name
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
                -H "Authorization: Bearer $PAT" "$API/releases/assets/$1")
        echo "  deleted old asset $2 (id=$1) http=$code"
}

STAGE="${1:-all}"

if [ "$STAGE" = "create" ] || [ "$STAGE" = "all" ]; then
        python3 - <<'EOF' > /tmp/v07_body.json
import json
body = """## چرا v0.7؟ (فیکس نهایی «منو نمیاد / آهنگ زشته»)

تشخیص: کاربر بایت‌های قدیمی v0.3 را از لینک‌های قدیمی چت دریافت می‌کرد — v0.5/v0.6 فیزیکاً آهنگ قدیمی داخلشان نبود. پس:

- **تمام لینک‌های قدیمی حالا همین فایل را می‌دهند**: assetهای v0.3 / v0.4 / v0.4.1 / v0.5.0 / v0.6.0 حذف و با همین v0.7 جایگزین شدند (با همان نام فایل قدیمی)
- **آهنگ v3 کاملاً جدید** (فا ماژور، سنتور ایرانی، درام فانک، ۶۹ ثانیه لوپ) که بلافاصله با باز شدن بازی پخش می‌شود — انگشت‌نگاری شنیداری
- **پلاک طلایی «بوقی v0.7 — بیلد ۸»** بالای صفحه بوت — انگشت‌نگاری بصری
- **همه‌ی ۱۲۳ فایل بازی داخل APK بدون فشرده‌سازی (STORE)** شدند — حذف کامل ریسک خواندن asset فشرده روی اندروید
- موسیقی از لحظه‌ی بوت استارت می‌خورد حتی اگر منو بالا نیاید
- versionCode 8، امضای همان کلید قبلی (آپدیت روی نسخه قبل بدون حذف نصب می‌نشیند)

**راه تشخیص نسخه‌ی درست:** حجم فایل ≈ ۶۶.۴MB + آهنگ جدید + پلاک طلایی v0.7 بالای صفحه بوت.
اگر منو باز نشد، صفحه‌ی بوت خودِ خطا را با لاگ نشان می‌دهد → از آن صفحه عکس بفرستید.
"""
print(json.dumps({
    "tag_name": "v0.7", "target_commitish": "main",
    "name": "بوقی v0.7 — لینک‌های قدیمی هم فایل جدید می‌دهند",
    "body": body, "draft": False, "prerelease": False
}))
EOF
        RID=$(auth -X POST -d @/tmp/v07_body.json "$API/releases" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id','ERR'))")
        echo "release v0.7 id=$RID"
        if [ "$RID" = "ERR" ]; then
                # maybe already exists -> fetch it
                RID=$(auth "$API/releases/tags/v0.7" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
                echo "existing release id=$RID"
        fi
        echo "$RID" > /tmp/v07_rid
        upload_asset "$RID" "BoghiCityTour_v0.7.apk"
        upload_asset "$RID" "BoghiCityTour.apk"
fi

if [ "$STAGE" = "patch_old" ] || [ "$STAGE" = "all" ]; then
        # v0.3, v0.4, v0.4.1, v0.5.0, v0.6.0 : delete old apk assets, upload v0.7 bytes
        for pair in "393371578:BoghiCityTour_v0.3_test.apk" \
                    "393474373:BoghiCityTour_v0.4_test.apk" \
                    "393658284:BoghiCityTour_v0.4.1.apk" \
                    "393672104:BoghiCityTour_v0.5.0.apk" \
                    "393690634:BoghiCityTour_v0.6.0.apk" \
                    "393690634:BoghiCityTour.apk"; do
                rid="${pair%%:*}"; name="${pair##*:}"
                aid=$(auth "$API/releases/$rid/assets" | python3 -c "
import json,sys
try:
    for a in json.load(sys.stdin):
        if a['name']=='$name': print(a['id']); break
except Exception: pass" )
                if [ -n "$aid" ]; then delete_asset "$aid" "$name"; fi
                upload_asset "$rid" "$name"
        done
        # warning line on top of old release bodies
        for rid in 393371578 393474373 393658284 393672104 393690634; do
                auth "$API/releases/$rid" | python3 -c "
import json,sys
d=json.load(sys.stdin)
warn='⚠️ فایل‌های این ریلیز قدیمی جایگزین شدند — هر لینک این صفحه اکنون همان **v0.7** را دانلود می‌کند.\n\n'
body={'body': warn + d.get('body','')}
print(json.dumps(body))" > /tmp/rel_patch.json
                auth -X PATCH -d @/tmp/rel_patch.json "$API/releases/$rid" > /dev/null
                echo "  body patched: release $rid"
        done
fi

echo "== DONE stage=$STAGE"
