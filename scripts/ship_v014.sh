#!/bin/bash
# Ship v0.14: create release + upload APK; then replace EVERY old release's
# APK assets with the SAME v0.14 bytes under the SAME old names.
set -euo pipefail
PAT=$(git config --get remote.origin.url | sed -n 's#.*x-access-token:\([^@]*\)@github.com.*#\1#p')
if [ -z "$PAT" ]; then echo "no token"; exit 1; fi
API="https://api.github.com/repos/ldrcoir/boghi-city-tour"
UP="https://uploads.github.com/repos/ldrcoir/boghi-city-tour"
APK=/home/z/my-project/download/BoghiCityTour_v0.14.apk
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
python3 - <<'PYEOF' > /tmp/v014_body.json
import json
body = """## بوقی v0.14 — کنسل شد؛ از اول، سبک کلاچ و NFS 🏁🌃

**این دیگر بازی کودکانه نیست — مسابقه‌ی خیابانی واقعی از بالا:**

- **رانندگی واقعی** — فرمان، شتاب، ترمز؛ ماشین با فیزیک واقعی می‌چرخد و لیز می‌خورد (نه دیگر آن پرش‌های مهدکودکی!)
- **دریفت دست‌برقه** — ترمز + فرمان = لاستیک جیغ می‌کشد، روی آسفالت رد سیاه می‌ماند، دود بلند می‌شود
- **نیترو سبک NFS** — دکمه‌ی آبی؛ شعله از اگزوز، دوربین باز می‌شود، خطوط سرعت
- **ترافیک زنده** — تاکسی و وانت و پراید تو خیابان؛ زدن با آن‌ها یعنی کرش واقعی
- **۳ رقیب هوشمند** — توی پیچ کند می‌کنند، از راه میان؛ جایگاه زنده «۴/۱» بالای صفحه
- **شهر شبانه** — ساختمان‌های نئون‌دار، چراغ خیابان، نور جلوی ماشین در تاریکی
- **۲ دور دور پیست محله** — با خط استارت شطرنجی و زنگ تکمیل دور
- **گیج سرعت عقربه‌ای** — کیلومتر واقعی؛ با نیترو تا ۲۰۰!
- **صدا کامل شد** — موتور، جیغ لاستیک موقع دریفت، ووش نیترو، کرش، سکه، شمارش معکوس
- **ماشین‌ها واقعی شدند** — ۲۰ ماشین ایرانی از بالا، بدون هیچ چشم کارتونی

نسخه: versionCode 15 / versionName 0.13 — امضای همان کلید همیشگی (روی نسخه‌ی قبلی مستقیم آپدیت می‌شود)

**نکته حجم:** APK حدود ۶۸ مگابایت است."""
print(json.dumps({
	"tag_name": "v0.14", "target_commitish": "main",
	"name": "بوقی v0.14 — مسابقه شبانه به سبک کلاچ/NFS",
	"body": body, "draft": False, "prerelease": False
}))
PYEOF
RID=$(auth -X POST "$API/releases" -d @/tmp/v014_body.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id', d.get('errors','ERR')))")
echo "release id: $RID"
case "$RID" in
	''|*[!0-9]*) echo "create failed"; exit 1;;
esac
upload_asset "$RID" "BoghiCityTour_v0.14.apk"
echo "== replacing old releases' APK assets =="
auth "$API/releases?per_page=50" | python3 -c "
import json, sys
for r in json.load(sys.stdin):
	if r['tag_name'] == 'v0.14': continue
	for a in r.get('assets', []):
		if a['name'].endswith('.apk'):
			print(f\"{r['tag_name']}|{a['name']}|{a['id']}\")
" | while IFS='|' read -r tag name aid; do
		echo "  $tag / $name"
		delete_asset "$aid"
		upload_asset "$RID" "$name" || upload_asset "$(auth "$API/releases/tags/$tag" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')" "$name"
done
echo SHIP-DONE
