import Foundation

/// 메뉴바 앱 ↔ 위젯이 공유하는 사용량 스냅샷.
/// 앱이 저장하고 위젯이 읽는다. 저장 위치는 App Group 컨테이너 경로.
struct UsageSnapshot: Codable {
    var fiveHourUsed: Double      // 0...1
    var fiveHourReset: Date?
    var weeklyUsed: Double        // 0...1
    var weeklyReset: Date?
    var updatedAt: Date

    static let appGroup = "group.com.claudeusage.shared"
    static let fileName = "usage.json"

    /// 저장/읽기 위치.
    /// - 샌드박스(위젯)면 App Group 컨테이너 API가 그 경로를 돌려준다.
    /// - 비샌드박스(앱)면 같은 위치를 리터럴 경로로 직접 가리킨다(둘 다 동일 디렉터리).
    static var fileURL: URL {
        if let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return container.appendingPathComponent(fileName)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/\(appGroup)/\(fileName)")
    }

    static func load() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(UsageSnapshot.self, from: data)
    }

    func save() {
        let dir = Self.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(self) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
