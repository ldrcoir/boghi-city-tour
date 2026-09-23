#!/bin/bash
# Ship v0.9: create release, upload APK (2 names), then replace EVERY old
# release's APK assets with the SAME v0.9 bytes under the SAME old names.
set -euo pipefail
source /home/z/my-project/.secrets.env
PAT="${PAT:?set PAT}"
API="https://api.github.com/repos/ldrcoir/boghi-city-tour"
UP="https://uploads.github.com/repos/ldrcoir/boghi-city-tour"
APK=/home/z/my-project/download/BoghiCityTour_v0.9.apk

auth() { curl -s -H "Authorization: Bearer $PAT" "$@"; }

upload_asset() { # release_id asset_name
        local rid="$1" name="$2" i code
        for i in 1 2 3; do
                code=$(curl -s -o /tmp/up.json -w "%{http_code}" \
                        -H "Authorization: Bearer $PAT" \
                        -H "Content-Type: application/octet-stream" \
                        --data-binary @"$APK" \
                        "$UP/releases/$rid/assets?name=$name")
                if [ "$code" = "201" ]; then
                        echo "  uploaded $name -> $rid (201)"; return 0
                fi
                echo "  retry $i: $name got $code $(head -c 150 /tmp/up.json)"; sleep 5
        done
        return 1
}

delete_asset() {
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
                -H "Authorization: Bearer $PAT" "$API/releases/assets/$1")
        echo "  deleted asset id=$1 http=$code"
}

STAGE="${1:-all}"

if [ "$STAGE" = "create" ] || [ "$STAGE" = "all" ]; then
        python3 - <<'EOF' > /tmp/v09_body.json
import json
body = """## بوقی v0.9 — ماشین‌های زنده 🚗✨

هنر جدید کامل ناوگان — همان درشتی و جزئیاتی که کاربر تأیید کرد (رفرنس‌های hero_car):

- **۱۶ ماشین با هنر جدید چاق‌وبراق**: چشم‌های درشت روی شیشه، لبخند، رنگ براق استودیویی — همه یکدست
- **۴ ماشین مسابقه‌ای جدید رنگی**: پراید آبی مسابقه‌ای (۴۸۰۰)، پژو سبز مسابقه‌ای (۵۴۰۰)، شاهین سفید (۶۰۰۰)، دنا سرخ کاپیتان (۶۸۰۰)
- **موسیقی جدید «ماریمبای محله»**: نرم و شاد بچگانه — ماریمبا + جعبه‌موزیک + یوکللی (جایگزین سبک سنتور-فانک)
- **پس‌زمینه‌ی نقاشی منو**: برج آزادی + میلاد + پیست غروب (نسخه‌ی نقاشی رفرنس track_tehran)
- **فیکس مهم: دکمه‌های منو روی گوشی**: کانتینر تمام‌صفحه‌ی پنل مأموریت‌ها لمس همه‌ی صفحه را می‌بلعید — حالا همه‌ی دکمه‌ها زنده‌اند (با تست تپ واقعی خودکار هم پوش داده شد)

نسخه: versionCode 10 / versionName 0.9 — پلاک طلایی «بوقی v0.9 — بیلد ۱۰»

**نکته حجم:** APK حدود ۶۶ مگابایت است؛ بعد از نصب اندروید فضا برای فایل‌های Extract شده اضافه می‌کند و «حجم برنامه» حدود ۱۴۰MB نمایش داده می‌شود — طبیعی است و به معنی اضافه‌کاری نیست.
"""
print(json.dumps({
    "tag_name": "v0.9", "target_commitish": "main",
    "name": "بوقی v0.9 — ماشین‌های زنده + فیکس لمس دکمه‌ها",
    "body": body, "draft": False, "prerelease": False
}))
EOF
        RID=$(auth -X POST -d @/tmp/v09_body.json "$API/releases" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id','ERR'))")
        if [ "$RID" = "ERR" ]; then
                RID=$(auth "$API/releases/tags/v0.9" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
        fi
        echo "release v0.9 id=$RID"
        upload_asset "$RID" "BoghiCityTour_v0.9.apk"
        upload_asset "$RID" "BoghiCityTour.apk"
fi

if [ "$STAGE" = "patch_old" ] || [ "$STAGE" = "all" ]; then
        # همه ریلیزهای قدیمی: assetهای APK حذف و بایت v0.9 با همان نام آپلود می‌شود
        for pair in "393747106:BoghiCityTour_v0.7.apk" \
                    "393747106:BoghiCityTour.apk" \
                    "393690634:BoghiCityTour_v0.6.0.apk" \
                    "393690634:BoghiCityTour.apk" \
                    "393672104:BoghiCityTour_v0.5.0.apk" \
                    "393658284:BoghiCityTour_v0.4.1.apk" \
                    "393474373:BoghiCityTour_v0.4_test.apk" \
                    "393371578:BoghiCityTour_v0.3_test.apk"; do
                rid="${pair%%:*}"; name="${pair##*:}"
                aid=$(auth "$API/releases/$rid/assets" | python3 -c "
import json,sys
try:
    for a in json.load(sys.stdin):
        if a['name']=='$name': print(a['id']); break
except Exception: pass")
                if [ -n "$aid" ]; then delete_asset "$aid"; fi
                upload_asset "$rid" "$name"
        done
        # ریلیز v0.8 — assetهایش پیدا می‌شوند از API
        V08RID=$(auth "$API/releases/tags/v0.8" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
        for name in BoghiCityTour_v0.8.apk BoghiCityTour.apk; do
                aid=$(auth "$API/releases/$V08RID/assets" | python3 -c "
import json,sys
try:
    for a in json.load(sys.stdin):
        if a['name']=='$name': print(a['id']); break
except Exception: pass")
                if [ -n "$aid" ]; then delete_asset "$aid"; fi
                upload_asset "$V08RID" "$name"
        done
        # هشدار روی بدنه ریلیزهای قدیمی (بدنه قبلی حذف و با هشدار تمیز جایگزین)
        for rid in "$V08RID" 393747106 393690634 393672104 393658284 393474373 393371578; do
                auth "$API/releases/$rid" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if d.get('tag_name')=='v0.9': sys.exit(0)
warn='⚠️ فایل‌های این ریلیز جایگزین شدند — هر لینک این صفحه اکنون همان **v0.9** را دانلود می‌کند (ماشین‌های زنده + فیکس لمس دکمه‌ها).\n\n'
print(json.dumps({'body': warn}))" > /tmp/rel_patch.json
                auth -X PATCH -d @/tmp/rel_patch.json "$API/releases/$rid" > /dev/null || true
                echo "  body checked: $rid"
        done
fi
echo "== DONE stage=$STAGE"
