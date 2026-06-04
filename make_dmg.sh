#!/bin/bash
# ClaudeUsage.app 을 드래그-설치형 DMG로 패키징한다.
# 사용법: ./make_dmg.sh [version]   (기본 0.1.0)
set -e
cd "$(dirname "$0")"

APP="ClaudeUsage.app"
VERSION="${1:-0.1.0}"
DMG="ClaudeUsage-${VERSION}.dmg"
VOL="Claude Usage"

[ -d "$APP" ] || { echo "먼저 ./build_app.sh 로 $APP 을 빌드하세요."; exit 1; }

STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # 드래그 대상

rm -f "$DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "✅ $DMG"
echo "   SHA256: $(shasum -a 256 "$DMG" | awk '{print $1}')"
