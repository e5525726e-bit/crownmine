#!/usr/bin/env bash
# 建置網頁版：讀取 dart_defines.json，填入 Google Maps 金鑰，輸出到 build/web
set -euo pipefail
cd "$(dirname "$0")/.."
KEY=$(python3 -c "import json;print(json.load(open('dart_defines.json'))['GOOGLE_PLACES_API_KEY'])")
flutter build web --release --dart-define-from-file=dart_defines.json --base-href "${BASE_HREF:-/}" --pwa-strategy=none
sed -i "s#__MAPS_API_KEY__#${KEY}#" build/web/index.html
echo "完成：build/web"
