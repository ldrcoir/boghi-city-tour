#!/bin/bash
# github_fast.sh <TOKEN> — هنگام رسیدن توکن تازه، فوری اجرا شود: bash scripts/github_fast.sh TOKEN
# ترتیب عملیات از سریع به کند تا حداکثر کار در عمر کوتاه توکن انجام شود.
set -uo pipefail
T="${1:?usage: github_fast.sh TOKEN}"
A="Authorization: Bearer $T"
H="Accept: application/vnd.github+json"
API="https://api.github.com"
REPO="boghi-city-tour"
ROOT=/home/z/my-project

LOGIN=$(curl -s -m 15 -H "$A" $API/user | python3 -c "import sys,json;print(json.load(sys.stdin).get('login',''))" 2>/dev/null)
if [ -z "$LOGIN" ]; then echo "❌ TOKEN DEAD — توکن باطل شده"; exit 1; fi
echo "✅ login=$LOGIN"

echo "== 1) create repo =="
curl -s -m 20 -X POST -H "$A" -H "$H" $API/user/repos -d "{\"name\":\"$REPO\",\"description\":\"بوقی: تور شهرها — Boghi: City Tour | Godot 4.7 living-car karting, Android+Windows, Season 1: Tehran (50 missions)\",\"private\":false,\"has_issues\":true,\"has_wiki\":false,\"auto_init\":false}" | head -c 220; echo

echo "== 2) push (HTTPS) =="
cd "$ROOT"
git push --progress "https://x-access-token:$T@github.com/$LOGIN/$REPO.git" main:main 2>&1 | tail -4

echo "== 3) create release v0.2 =="
RID=$(curl -s -m 20 -X POST -H "$A" -H "$H" $API/repos/$LOGIN/$REPO/releases -d "{\"tag_name\":\"v0.2\",\"target_commitish\":\"main\",\"name\":\"بوقی v0.2 — نسخه تست با چشم‌های نو\",\"body\":\"چشم‌های خوشگل و لبخند بزرگ روی بوقی قرمز\\nبوقی زرد جدید (۸۰۰ سکه)\\n۱۲ ماشین، نیترو، استاد فنر سیبیل‌دار با انیمیشن کار\\n\\nAPK را از پایین همین صفحه (Assets) دانلود کنید.\",\"draft\":false,\"prerelease\":false}" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('id','ERR'))" 2>/dev/null)
echo "release id=$RID"

if [ "$RID" != "ERR" ] && [ -n "$RID" ]; then
  echo "== 4) upload APK (69MB) =="
  curl -s -m 560 -X POST -H "$A" -H "$H" -H "Content-Type: application/vnd.android.package-archive" --data-binary @"$ROOT/download/BoghiCityTour_v0.2_test.apk" "https://uploads.github.com/repos/$LOGIN/$REPO/releases/$RID/assets?name=BoghiCityTour_v0.2_test.apk" | head -c 220; echo
else
  echo "⚠ release create failed (token?) — آپلود دستی: github.com/$LOGIN/$REPO/releases/new"
fi

echo "== 5) enable Pages (docs/) =="
curl -s -m 20 -X POST -H "$A" -H "$H" $API/repos/$LOGIN/$REPO/pages -d '{"source":{"branch":"main","path":"/docs"}}' | head -c 200; echo

echo "== DONE =="
echo "repo : https://github.com/$LOGIN/$REPO"
echo "apk  : https://github.com/$LOGIN/$REPO/releases/download/v0.2/BoghiCityTour_v0.2_test.apk"
echo "page : https://$LOGIN.github.io/$REPO/"
