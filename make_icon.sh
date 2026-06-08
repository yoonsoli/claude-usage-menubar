#!/bin/bash
# Icon/claude-usage-icon.svg → Icon/AppIcon.icns 를 생성한다.
# SVG는 qlmanage로 1024px PNG로 렌더한 뒤, sips로 모든 사이즈를 만들어 iconutil로 묶는다.
set -e
cd "$(dirname "$0")"

SVG="Icon/claude-usage-icon.svg"
OUT="Icon/AppIcon.icns"
[ -f "$SVG" ] || { echo "없음: $SVG"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1) SVG → 1024 PNG (Quick Look 렌더러 사용)
qlmanage -t -s 1024 -o "$TMP" "$SVG" >/dev/null 2>&1
SRC="$TMP/$(basename "$SVG").png"
[ -f "$SRC" ] || { echo "SVG 렌더 실패"; exit 1; }

# 2) iconset 구성
SET="$TMP/AppIcon.iconset"
mkdir -p "$SET"
gen() { sips -z "$2" "$2" "$SRC" --out "$SET/$1" >/dev/null; }
gen icon_16x16.png        16
gen icon_16x16@2x.png     32
gen icon_32x32.png        32
gen icon_32x32@2x.png     64
gen icon_128x128.png     128
gen icon_128x128@2x.png  256
gen icon_256x256.png     256
gen icon_256x256@2x.png  512
gen icon_512x512.png     512
gen icon_512x512@2x.png 1024

# 3) iconset → icns
iconutil -c icns "$SET" -o "$OUT"
echo "✅ $OUT"
