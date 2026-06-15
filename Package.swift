// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClaudeUsage",
    platforms: [.macOS(.v15)],   // Sequoia 이상 지원(Liquid Glass는 macOS 26+에서만 적용)
    targets: [
        .executableTarget(
            name: "ClaudeUsage",
            path: "Sources/ClaudeUsage"
        )
    ]
)
