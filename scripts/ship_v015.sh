#!/bin/bash
# Ship v0.15: create release + upload APK; then replace EVERY old release's
# APK assets with the SAME v0.15 bytes under the SAME old names.
set -euo pipefail
PAT=$(git -C /home/z/my-project/game config --get remote.origin.url | sed -n 's#.*x-access-token:\([^@]*\)@github.com.*#\1#p')
if [ -z "$PAT" ]; then echo "no token"; exit 1; fi
API="https://api.github.com/repos/ldrcoir/boghi-city-tour"
UP="https://uploads.github.com/repos/ldrcoir/boghi-city-tour"
APK=/home/z/my-project/download/BoghiCityTour_v0.15.apk
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
python3 - <<'PYEOF' > /tmp/v015_body.json
import json
body = """## بوقی v0.15 — وسواس واقعی‌بودن 🏁🌃

**این نسخه از پایین بازسازی شد — با وسواس روی هر جزئیات:**

### ⛔ مهم‌ترین فیکس
- **فرمان لمسی مرده بود!** یک لایه‌ی نامرئی تمام‌صفحه همه‌ی لمس‌ها را می‌بلعید — حالا فرمان با انگشت واقعاً جواب می‌دهد

### 🏙️ شهر واقعی
- **۲۷۰ ساختمان** چسبیده به هم مثل خیابان واقعی — با پنجره‌های روشن، آویز مغازه، تابلو نئون
- کوچه‌های بن‌بست، حیاط‌های سبز، درخت، ماشین‌های پارک‌شده با برخورد واقعی
- چراغ خیابان و استخر نور — خیابان دیگر سیاه‌چال نیست

### 🚗 ماشین‌های واقعی
- آناتومی واقعی از بالا: شیشه، سقف، لاستیک بیرون‌زده، چراغ جلو/عقب، آینه، سپر
- چراغ ترمز قرمز — هم مال تو، هم رقیب‌ها موقع ترمز در پیچ روشن می‌شود

### 🎧 صدای واقعی
- **گیربکس ۵ دنده** — دور موتور بالا می‌رود، دنده عوض می‌شود، صدای تعویض دنده
- صدای باد و غلتش جاده با سرعت
- جرقه موقع برخورد، پانچ نیترو، دود اگزوز درجا

### 🎮 منوی حرفه‌ای
- پلاک نئونی تمیز، بوقی زنده در خیابان پایین صفحه رد می‌شود، کلیک صدا دار

نسخه: versionCode 17 / versionName 0.15 — امضای همان کلید همیشگی (روی نسخه‌ی قبلی مستقیم آپدیت می‌شود)

**نکته حجم:** APK حدود ۸۷ مگابایت است (نقشه‌ی شهر با کیفیت ۱:۱)."""
print(json.dumps({
	"tag_name": "v0.15", "target_commitish": "main",
	"name": "بوقی v0.15 — وسواس واقعی‌بودن: شهر واقعی، فرمان لمسی فیکس شد",
	"body": body, "draft": False, "prerelease": False
}))
PYEOF
RID=$(auth -X POST "$API/releases" -d @/tmp/v015_body.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id', d.get('errors','ERR')))")
echo "release id: $RID"
case "$RID" in
	''|*[!0-9]*) echo "create failed"; exit 1;;
esac
upload_asset "$RID" "BoghiCityTour_v0.15.apk"
upload_asset "$RID" "BoghiCityTour.apk"
echo "== replacing old releases' APK assets =="
auth "$API/releases?per_page=50" | python3 -c "
import json, sys
for r in json.load(sys.stdin):
	if r['tag_name'] == 'v0.15': continue
	for a in r.get('assets', []):
		if a['name'].endswith('.apk'):
			print(f\"{r['tag_name']}|{a['name']}|{a['id']}\")
" | while IFS='|' read -r tag name aid; do
		echo "  $tag / $name"
		delete_asset "$aid"
		upload_asset "$RID" "$name" || upload_asset "$(auth "$API/releases/tags/$tag" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')" "$name"
done
echo SHIP-DONE
