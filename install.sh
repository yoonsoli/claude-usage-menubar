#!/bin/bash
#
# Claude Usage Menubar - one-line installer
#
#   curl -fsSL https://raw.githubusercontent.com/yoonsoli/claude-usage-menubar/main/install.sh | bash
#
# Downloads the latest release, installs to /Applications, clears the quarantine
# flag (the app is ad-hoc signed, not notarized), and launches it.
#
# NOTE: output is intentionally ASCII-only. When piped through `bash` under a
# non-UTF-8 locale, a multibyte char right after $VAR can corrupt parsing.
#
set -euo pipefail

REPO="yoonsoli/claude-usage-menubar"
APP="ClaudeUsage.app"
URL="https://github.com/${REPO}/releases/latest/download/ClaudeUsage.zip"
DEST="/Applications"

# Require macOS 26 (Tahoe) or later.
major="$(sw_vers -productVersion | cut -d. -f1)"
if [ "${major:-0}" -lt 26 ]; then
  echo "This app requires macOS 26 (Tahoe) or later. You have $(sw_vers -productVersion)." >&2
  exit 1
fi

# Use sudo only if /Applications is not writable.
SUDO=""
if [ ! -w "${DEST}" ]; then
  SUDO="sudo"
  echo "Note: ${DEST} is not writable; you may be prompted for your password."
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

echo "Downloading Claude Usage..."
curl -fsSL "${URL}" -o "${tmp}/ClaudeUsage.zip"

echo "Installing to ${DEST}/${APP} ..."
# Quit a running instance, if any.
osascript -e 'quit app "ClaudeUsage"' 2>/dev/null || true
pkill -f "${APP}/Contents/MacOS/ClaudeUsage" 2>/dev/null || true
sleep 1

${SUDO} rm -rf "${DEST:?}/${APP}"
${SUDO} ditto -x -k "${tmp}/ClaudeUsage.zip" "${DEST}"
# ad-hoc signed: clear quarantine so Gatekeeper does not block it.
${SUDO} xattr -dr com.apple.quarantine "${DEST}/${APP}" 2>/dev/null || true

echo "Launching..."
open "${DEST}/${APP}"
echo "Done. Claude Usage is installed in ${DEST}. Sign in to claude.ai when the login window appears."
