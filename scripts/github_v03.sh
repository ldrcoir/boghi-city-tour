#!/bin/bash
# github_v03.sh <TOKEN> — وقتی توکن با پرمیشن درست رسید، فوری اجرا کن:
#   bash scripts/github_v03.sh TOKEN
# توکن باید داشته باشد (fine-grained): Administration:Read&Write + Contents:Read&Write
# یا توکن classic با scope «repo».
set -uo pipefail
T="${1:?usage: github_v03.sh TOKEN}"
A="Authorization: Bearer $T"
H="Accept: application/vnd.github+json"
API="https://api.github.com"
REPO="boghi-city-tour"
ROOT=/home/z/my-project
APK="$ROOT/download/BoghiCityTour_v0.3_test.apk"

LOGIN=$(curl -s -m 15 -H "$A" $API/user | python3 -c "import sys,json;print(json.load(sys.stdin).get('login',''))" 2>/dev/null)
if [ -z "$LOGIN" ]; then echo "❌ TOKEN DEAD"; exit 1; fi
echo "✅ login=$LOGIN"

echo "== 1) create repo (needs Administration:write) =="
CREATE=$(curl -s -m 20 -X POST -H "$A" -H "$H" $API/user/repos -d "{\"name\":\"$REPO\",\"description\":\"Boghi City Tour — living-car karting, Godot 4.7, Android+Windows, Season 1: Tehran (50 missions)\",\"private\":false,\"has_issues\":true,\"auto_init\":false}")
if echo "$CREATE" | grep -q '"full_name"'; then
  echo "✅ repo created"
else
  echo "⚠ repo create failed: $(echo "$CREATE" | head -c 150)"
  echo "→ fallback: trying release on existing repo caspian-academy"
  REPO="caspian-academy"
fi

echo "== 2) push source =="
cd "$ROOT"
git push "https://x-access-token:$T@github.com/$LOGIN/$REPO.git" main:main 2>&1 | tail -2

echo "== 3) create release =="
RID=$(curl -s -m 20 -X POST -H "$A" -H "$H" $API/repos/$LOGIN/$REPO/releases -d "{\"tag_name\":\"v0.3\",\"target_commitish\":\"main\",\"name\":\"بوقی v0.3 — ماشین‌های زبان‌باز\",\"body\":\"هر ماشین شخصیت و صدای خودش را دارد؛ بوقی شیطون می‌گوید منو انتخاب کن!\\nبوست مخفی بوقی + لوگوی رسمی\\nفصل ۱ تهران — ۵۰ مأموریت — ۱۲ ماشین — نیترو\\n\\nAPK را از Assets پایین همین صفحه دانلود کنید.\",\"draft\":false,\"prerelease\":false}" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('id','ERR'))" 2>/dev/null)
echo "release id=$RID"

if [ "$RID" != "ERR" ] && [ -n "$RID" ]; then
  echo "== 4) upload APK (70MB) =="
  curl -s -m 550 -X POST -H "$A" -H "$H" -H "Content-Type: application/vnd.android.package-archive" --data-binary @"$APK" "https://uploads.github.com/repos/$LOGIN/$REPO/releases/$RID/assets?name=BoghiCityTour_v0.3_test.apk" | python3 -c "import sys,json;d=json.load(sys.stdin);print('UPLOAD:',d.get('state',d))" 2>/dev/null
else
  echo "⚠ release failed"
fi

echo "== 5) Pages (docs/) =="
curl -s -m 20 -X POST -H "$A" -H "$H" $API/repos/$LOGIN/$REPO/pages -d '{"source":{"branch":"main","path":"/docs"}}' | head -c 150; echo

echo "== DONE =="
echo "repo : https://github.com/$LOGIN/$REPO"
echo "apk  : https://github.com/$LOGIN/$REPO/releases/download/v0.3/BoghiCityTour_v0.3_test.apk"
echo "page : https://$LOGIN.github.io/$REPO/"
