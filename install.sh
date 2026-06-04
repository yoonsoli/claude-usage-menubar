#!/bin/bash
#
# Claude Usage Menubar — one-line installer
#
#   curl -fsSL https://raw.githubusercontent.com/yoonsoli/claude-usage-menubar/main/install.sh | bash
#
# Downloads the latest release, installs to /Applications, clears the quarantine
# flag (the app is ad-hoc signed, not notarized), and launches it.
#
set -euo pipefail

REPO="yoonsoli/claude-usage-menubar"
APP="ClaudeUsage.app"
URL="https://github.com/${REPO}/releases/latest/download/ClaudeUsage.zip"
DEST="/Applications"

# --- macOS 26 (Tahoe) 이상 확인 ---------------------------------------------
major="$(sw_vers -productVersion | cut -d. -f1)"
if [ "${major:-0}" -lt 26 ]; then
  echo "⚠️  This app requires macOS 26 (Tahoe) or later. You have $(sw_vers -productVersion)." >&2
  exit 1
fi

# --- 설치 위치 쓰기 권한 확인 -----------------------------------------------
SUDO=""
if [ ! -w "$DEST" ]; then
  SUDO="sudo"
  echo "→ $DEST is not writable; you may be prompted for your password."
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "↓ Downloading Claude Usage…"
curl -fsSL "$URL" -o "$tmp/ClaudeUsage.zip"

echo "→ Installing to $DEST/$APP…"
# 실행 중이면 종료
osascript -e 'quit app "ClaudeUsage"' 2>/dev/null || true
pkill -f "$APP/Contents/MacOS/ClaudeUsage" 2>/dev/null || true
sleep 1

$SUDO rm -rf "$DEST/$APP"
$SUDO ditto -x -k "$tmp/ClaudeUsage.zip" "$DEST"
# ad-hoc 서명이라 Gatekeeper가 막지 않도록 quarantine 제거
$SUDO xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

echo "▶ Launching…"
open "$DEST/$APP"
echo "✅ Claude Usage installed. Sign in to claude.ai when the login window appears."
