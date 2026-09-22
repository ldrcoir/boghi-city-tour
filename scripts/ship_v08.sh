#!/bin/bash
# Ship v0.8: create release, upload new APK (2 names), then replace EVERY old
# release's APK assets with the SAME v0.8 bytes under the SAME old names.
set -euo pipefail
source /home/z/my-project/.secrets.env
PAT="${PAT:?set PAT}"
API="https://api.github.com/repos/ldrcoir/boghi-city-tour"
UP="https://uploads.github.com/repos/ldrcoir/boghi-city-tour"
APK=/home/z/my-project/download/BoghiCityTour_v0.8.apk

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
        python3 - <<'EOF' > /tmp/v08_body.json
import json
body = """## بوقی v0.8 — فیکس چیدمان منو روی گوشی (اسکرین‌شات کاربر تحلیل شد)

تشخیص از اسکرین‌شات واقعی گوشی: پس‌زمینه و برچسب نسخه (anchor-محور) رندر می‌شدند ولی پنل/تایتل/ماشین‌ها (position ثابت) غایب بودند + presetهای anchor در لوکیشن فارسی آینه می‌شدند.

- **کل منو به چیدمان anchor-محور بازنویسی شد** — همان سازوکاری که روی گوشی کاربر اثباتاً کار می‌کند
- **جهت چیدمان LTR قفل شد** تا در لوکیشن فارسی آینه نشود (متن فارسی سر جای خودش است)
- **نگهبان تشخیصی**: اگر پنل منو باز هم روی دید نباشد، هندسه‌ی واقعی گوشی (viewport/rect/locale) روی صفحه نشان داده می‌شود — عکس بگیرید و بفرستید
- اسکریپت‌ها باینری شدند (script_export_mode=2) — ضدکرک + لود سریع‌تر
- نسخه: versionCode 9 / versionName 0.8 — پلاک طلایی «بوقی v0.8 — بیلد ۹»

**توجه:** کلید امضا تازه‌سازی شده — اگر نصب نشد اول نسخه قبلی را uninstall کنید.
راه تشخیص نسخه درست: پلاک طلایی v0.8 بالای صفحه بوت + برچسب «v0.8 (build 9)» گوشه منو.
"""
print(json.dumps({
    "tag_name": "v0.8", "target_commitish": "main",
    "name": "بوقی v0.8 — فیکس چیدمان منو + نگهبان تشخیصی",
    "body": body, "draft": False, "prerelease": False
}))
EOF
        RID=$(auth -X POST -d @/tmp/v08_body.json "$API/releases" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id','ERR'))")
        if [ "$RID" = "ERR" ]; then
                RID=$(auth "$API/releases/tags/v0.8" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
        fi
        echo "release v0.8 id=$RID"
        upload_asset "$RID" "BoghiCityTour_v0.8.apk"
        upload_asset "$RID" "BoghiCityTour.apk"
fi

if [ "$STAGE" = "patch_old" ] || [ "$STAGE" = "all" ]; then
        # همه ریلیزهای قدیمی: assetهای APK حذف و بایت v0.8 با همان نام آپلود می‌شود
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
        # هشدار روی بدنه ریلیزهای قدیمی
        for rid in 393747106 393690634 393672104 393658284 393474373 393371578; do
                auth "$API/releases/$rid" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if d.get('tag_name')=='v0.8': sys.exit(0)
warn='⚠️ فایل‌های این ریلیز جایگزین شدند — هر لینک این صفحه اکنون همان **v0.8** را دانلود می‌کند.\n\n'
print(json.dumps({'body': warn + d.get('body','')}))" > /tmp/rel_patch.json
                auth -X PATCH -d @/tmp/rel_patch.json "$API/releases/$rid" > /dev/null || true
                echo "  body checked: $rid"
        done
fi
echo "== DONE stage=$STAGE"
