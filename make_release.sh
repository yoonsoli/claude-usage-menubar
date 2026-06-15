#!/bin/bash
# Tahoe(macOS 26) / Sequoia(macOS 15) 두 변형을 빌드해 릴리스 에셋 4개를 만든다.
#   ClaudeUsage-Tahoe.zip   ClaudeUsage-Tahoe.dmg
#   ClaudeUsage-Sequoia.zip ClaudeUsage-Sequoia.dmg
#
# 사용법: ./make_release.sh            # 에셋만 빌드
#         ./make_release.sh v0.1.5     # 빌드 후 gh 릴리스까지 생성
set -e
cd "$(dirname "$0")"

TAG="${1:-}"
APP="ClaudeUsage.app"

package() {   # $1 = tahoe|sequoia, $2 = Tahoe|Sequoia
    local variant="$1" label="$2"
    echo "===== ${label} 빌드 ====="
    ./build_app.sh "$variant" >/dev/null
    rm -f "ClaudeUsage-${label}.zip" "ClaudeUsage-${label}.dmg"

    # zip (한 줄 설치 / 수동 다운로드용)
    ditto -c -k --sequesterRsrc --keepParent "$APP" "ClaudeUsage-${label}.zip"

    # 드래그-설치형 dmg
    local stage; stage="$(mktemp -d)"
    cp -R "$APP" "$stage/"
    ln -s /Applications "$stage/Applications"
    hdiutil create -volname "Claude Usage (${label})" -srcfolder "$stage" \
        -ov -format UDZO "ClaudeUsage-${label}.dmg" >/dev/null
    rm -rf "$stage"

    echo "  ClaudeUsage-${label}.zip  $(shasum -a 256 "ClaudeUsage-${label}.zip" | awk '{print $1}')"
    echo "  ClaudeUsage-${label}.dmg  $(shasum -a 256 "ClaudeUsage-${label}.dmg" | awk '{print $1}')"
}

package tahoe   Tahoe
package sequoia Sequoia
rm -rf "$APP" build_widget

echo "✅ 에셋 4개 생성 완료"

if [ -n "$TAG" ]; then
    echo "===== gh 릴리스 ${TAG} 생성 ====="
    gh release create "$TAG" --title "$TAG" --latest \
        --notes "macOS 26 (Tahoe) and macOS 15 (Sequoia) builds. The one-line installer auto-detects your macOS and grabs the right one." \
        ClaudeUsage-Tahoe.zip ClaudeUsage-Tahoe.dmg \
        ClaudeUsage-Sequoia.zip ClaudeUsage-Sequoia.dmg
fi
