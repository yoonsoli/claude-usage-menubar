// swift-tools-version: 6.2
import PackageDescription
import Foundation

// 배포 타깃을 변형별로 바꾼다: CU_MACOS_MIN=26 → Tahoe(.v26), 그 외 → Sequoia(.v15).
// build_app.sh 가 이 환경변수를 설정한다(기본 Sequoia 플로어).
let minMacOS: SupportedPlatform.MacOSVersion =
    (ProcessInfo.processInfo.environment["CU_MACOS_MIN"] == "26") ? .v26 : .v15

let package = Package(
    name: "ClaudeUsage",
    platforms: [.macOS(minMacOS)],
    targets: [
        .executableTarget(
            name: "ClaudeUsage",
            path: "Sources/ClaudeUsage"
        )
    ]
)
