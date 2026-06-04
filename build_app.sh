#!/bin/bash
# ClaudeUsage 메뉴바 앱 + 위젯 익스텐션을 .app 번들로 빌드한다.
set -e
cd "$(dirname "$0")"

APP="ClaudeUsage.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
GROUP="group.com.claudeusage.shared"

echo "[1/5] 메뉴바 앱(Swift) 릴리스 빌드…"
swift build -c release
BIN=".build/release/ClaudeUsage"

echo "[2/5] .app 번들 구성…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns"
cp "$BIN" "$APP/Contents/MacOS/ClaudeUsage"

cat > "$APP/Contents/Info.plist" <<'PLIST'
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
    <key>LSUIElement</key>            <true/>
    <key>LSMinimumSystemVersion</key>  <string>26.0</string>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

echo "[3/5] 위젯 익스텐션(WidgetKit) 컴파일… ($ARCH)"
WBIN="build_widget/ClaudeUsageWidget"
mkdir -p build_widget
swiftc \
    -sdk "$SDK" \
    -target "${ARCH}-apple-macos26.0" \
    -parse-as-library -O \
    -framework WidgetKit -framework SwiftUI \
    Widget/WidgetMain.swift Sources/ClaudeUsage/UsageSnapshot.swift Sources/ClaudeUsage/Localization.swift \
    -o "$WBIN"

echo "[4/5] .appex 번들 내장…"
APPEX="$APP/Contents/PlugIns/ClaudeUsageWidget.appex"
mkdir -p "$APPEX/Contents/MacOS"
cp "$WBIN" "$APPEX/Contents/MacOS/ClaudeUsageWidget"

cat > "$APPEX/Contents/Info.plist" <<'PLIST'
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
    <key>LSMinimumSystemVersion</key>     <string>26.0</string>
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

echo "✅ 완료: $APP  (메뉴바 앱 + 정사각형 위젯)"
