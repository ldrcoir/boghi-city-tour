#!/bin/bash
# Ship v0.10: create release + upload APK; then replace EVERY old release's
# APK assets with the SAME v0.10 bytes under the SAME old names.
set -euo pipefail
source /home/z/my-project/.secrets.env
API="https://api.github.com/repos/ldrcoir/boghi-city-tour"
UP="https://uploads.github.com/repos/ldrcoir/boghi-city-tour"
APK=/home/z/my-project/download/BoghiCityTour_v0.10.apk
auth() { curl -s -H "Authorization: Bearer $PAT" "$@"; }
upload_asset() {
        local rid="$1" name="$2" i code
        for i in 1 2 3; do
                code=$(curl -s -o /tmp/up.json -w "%{http_code}" \
                        -H "Authorization: Bearer $PAT" \
                        -H "Content-Type: application/octet-stream" \
                        --data-binary @"$APK" \
                        "$UP/releases/$rid/assets?name=$name")
                if [ "$code" = "201" ]; then echo "  uploaded $name -> $rid (201)"; return 0; fi
                echo "  retry $i: $name got $code $(head -c 120 /tmp/up.json)"; sleep 5
        done; return 1
}
delete_asset() {
        curl -s -o /dev/null -w "  deleted asset %{http_code}\n" -X DELETE \
                -H "Authorization: Bearer $PAT" "$API/releases/assets/$1"
}
python3 - <<'PYEOF' > /tmp/v010_body.json
import json
body = """## بوقی v0.10 — بخش داستان، کات‌سین و صدای فارسی 🚗🎬

اولین نسخه‌ی قابل بازی کامل با هر سه بخش:

- **سه بخش منو: مسابقه / مأموریت / زندگی محله**
- **موتور کات‌سین + اپیزود ۱ «سیب‌زمینی و سنگک»**: بوقی و نیسان آبی حرف می‌زنند، زن اکبر داد می‌زند — دیالوگ RTL تایپ‌رایتر
- **مسابقه آنلاین با جایگزین هوشمند**: اگر حریف آنلاین پیدا نشد، بعد از چند ثانیه AI اکبر پشت فرمون می‌نشیند
- **BVAULT**: سناریو و داده‌ها در کانتینر کدشده ChaCha20 — ضد استخراج
- **حذف کامل صدای زنگ لاله‌زبان قبلی**

نسخه: versionCode 11 / versionName 0.10 — امضای همان کلید همیشگی (روی نسخه‌های قبلی آپدیت می‌شود)

**نکته حجم:** APK حدود ۶۸ مگابایت است؛ بعد از نصب «حجم برنامه» بیشتر نمایش داده می‌شود — طبیعی است.
"""
print(json.dumps({
    "tag_name": "v0.10", "target_commitish": "main",
    "name": "بوقی v0.10 — داستان، کات‌سین و سه بخش منو",
    "body": body, "draft": False, "prerelease": False
}))
PYEOF
RID=$(auth -X POST "$API/releases" -d @/tmp/v010_body.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id', d.get('errors','ERR')))")
echo "release id: $RID"
case "$RID" in
  ''|*[!0-9]*) echo "create failed"; exit 1;;
esac
upload_asset "$RID" "BoghiCityTour_v0.10.apk"
echo "== replacing old releases' APK assets =="
auth "$API/releases?per_page=50" | python3 -c "
import json, sys
for r in json.load(sys.stdin):
    if r['tag_name'] == 'v0.10': continue
    for a in r.get('assets', []):
        if a['name'].endswith('.apk'):
            print(f\"{r['tag_name']}|{a['name']}|{a['id']}\")
" | while IFS='|' read -r tag name aid; do
        echo "  $tag / $name"
        delete_asset "$aid"
        upload_asset "$RID" "$name" || upload_asset "$(auth "$API/releases/tags/$tag" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')" "$name"
done
echo SHIP-DONE
