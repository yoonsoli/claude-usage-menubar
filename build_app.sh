#!/bin/bash
# ClaudeUsage 메뉴바 앱 + 위젯 익스텐션을 .app 번들로 빌드한다.
#
# 사용법: ./build_app.sh [tahoe|sequoia]   (기본 tahoe)
#   tahoe   : macOS 26 타깃 — 네이티브 Liquid Glass
#   sequoia : macOS 15 타깃 — ultraThinMaterial 폴백
#
# 두 변형은 배포 타깃(LSMinimumSystemVersion / minos)만 다르다.
# 소스의 `if #available(macOS 26.0, *)` 가드가 런타임 효과를 결정한다.
# 바이너리는 항상 유니버설(arm64 + x86_64) — Apple Silicon·Intel 모두 실행.
set -e
cd "$(dirname "$0")"

VARIANT="${1:-tahoe}"
case "$VARIANT" in
    tahoe)   MINOS="26.0"; CU_MIN="26" ;;
    sequoia) MINOS="15.0"; CU_MIN="15" ;;
    *) echo "사용법: $0 [tahoe|sequoia]" >&2; exit 1 ;;
esac

APP="ClaudeUsage.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
GROUP="group.com.claudeusage.shared"

echo "[1/5] 메뉴바 앱(Swift) 릴리스 빌드… (${VARIANT}, macOS ${MINOS}, universal)"
# 배포 타깃은 Package.swift가 CU_MACOS_MIN 환경변수로 결정한다(.v26 / .v15).
# --manifest-cache none: 변형 전환 시 캐시된 매니페스트가 재사용되지 않도록 한다.
CU_MACOS_MIN="$CU_MIN" swift build -c release --arch arm64 --arch x86_64 --manifest-cache none
BIN=".build/apple/Products/Release/ClaudeUsage"

echo "[2/5] .app 번들 구성…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns"
cp "$BIN" "$APP/Contents/MacOS/ClaudeUsage"

# 앱 아이콘(없으면 SVG에서 생성)
[ -f Icon/AppIcon.icns ] || ./make_icon.sh
cp Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>ClaudeUsage</string>
    <key>CFBundleDisplayName</key>     <string>Claude Usage</string>
    <key>CFBundleIdentifier</key>      <string>com.claudeusage.menubar</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleExecutable</key>      <string>ClaudeUsage</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundleIconName</key>        <string>AppIcon</string>
    <key>LSUIElement</key>            <true/>
    <key>LSMinimumSystemVersion</key>  <string>${MINOS}</string>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

echo "[3/5] 위젯 익스텐션(WidgetKit) 컴파일… (universal, macOS ${MINOS})"
WBIN="build_widget/ClaudeUsageWidget"
mkdir -p build_widget
WSRC=(Widget/WidgetMain.swift Sources/ClaudeUsage/UsageSnapshot.swift Sources/ClaudeUsage/Localization.swift)
for arch in arm64 x86_64; do
    swiftc \
        -sdk "$SDK" \
        -target "${arch}-apple-macos${MINOS}" \
        -parse-as-library -O \
        -framework WidgetKit -framework SwiftUI \
        "${WSRC[@]}" \
        -o "${WBIN}-${arch}"
done
lipo -create "${WBIN}-arm64" "${WBIN}-x86_64" -o "$WBIN"

echo "[4/5] .appex 번들 내장…"
APPEX="$APP/Contents/PlugIns/ClaudeUsageWidget.appex"
mkdir -p "$APPEX/Contents/MacOS"
cp "$WBIN" "$APPEX/Contents/MacOS/ClaudeUsageWidget"

cat > "$APPEX/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key> <string>en</string>
    <key>CFBundleDisplayName</key>        <string>Claude Usage Widget</string>
    <key>CFBundleExecutable</key>         <string>ClaudeUsageWidget</string>
    <key>CFBundleIdentifier</key>         <string>com.claudeusage.menubar.ClaudeUsageWidget</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key>               <string>ClaudeUsageWidget</string>
    <key>CFBundlePackageType</key>        <string>XPC!</string>
    <key>CFBundleShortVersionString</key> <string>0.1</string>
    <key>CFBundleVersion</key>            <string>1</string>
    <key>LSMinimumSystemVersion</key>     <string>${MINOS}</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
PLIST

# 앱·위젯이 데이터를 공유할 App Group 엔타이틀먼트
cat > build_widget/shared.entitlements <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array><string>${GROUP}</string></array>
</dict>
</plist>
PLIST

echo "[5/5] 코드 서명(애드혹, App Group 엔타이틀먼트)…"
# 위젯 먼저, 그다음 앱 전체(deep)
codesign --force --sign - --entitlements build_widget/shared.entitlements "$APPEX" 2>/dev/null
codesign --force --deep --sign - --entitlements build_widget/shared.entitlements "$APP" 2>/dev/null
echo "  서명 검증:" && codesign -v "$APP" 2>&1 && echo "  OK"

echo "✅ 완료: $APP  (${VARIANT}, macOS ${MINOS}+ · universal arm64+x86_64)"
