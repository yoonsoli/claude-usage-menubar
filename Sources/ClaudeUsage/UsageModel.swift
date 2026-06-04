import Foundation

/// 하나의 사용량 윈도우(5시간 또는 주간).
struct UsageWindow: Equatable {
    var used: Double?
    var limit: Double?
    var remaining: Double?
    var resetsAt: Date?

    /// 사용 비율(0...1). used/limit 우선, 없으면 remaining/limit로 역산.
    var usedFraction: Double? {
        if let u = used, let l = limit, l > 0 { return clamp(u / l) }
        if let r = remaining, let l = limit, l > 0 { return clamp(1 - r / l) }
        return nil
    }

    var remainingFraction: Double? {
        guard let f = usedFraction else { return nil }
        return clamp(1 - f)
    }

    private func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
}

/// 가로챈 usage 응답을 파싱한 결과.
struct CapturedUsage: Equatable {
    var fiveHour: UsageWindow?
    var weekly: UsageWindow?
    var capturedAt: Date = .now
    var sourceURL: String = ""
    var rawJSON: String = ""
}

/// 응답 JSON 구조를 모를 때를 대비한 best-effort 파서.
/// remaining/used/limit/utilization/resets_at 류 키를 재귀로 찾아 윈도우를 구성한다.
enum UsageParser {
    static func parse(jsonData: Data, url: String) -> CapturedUsage {
        var result = CapturedUsage()
        result.sourceURL = url
        result.rawJSON = pretty(jsonData)

        guard let root = try? JSONSerialization.jsonObject(with: jsonData) else { return result }

        var windows: [(label: String, window: UsageWindow)] = []
        walk(root, label: "root", into: &windows)

        for (label, w) in windows {
            let l = label.lowercased()
            if result.fiveHour == nil,
               l.contains("five") || l.contains("5h") || l.contains("5_h")
                || l.contains("hour") || l.contains("session") {
                result.fiveHour = w
            } else if result.weekly == nil,
                      l.contains("week") || l.contains("seven")
                        || l.contains("7d") || l.contains("7_d") {
                result.weekly = w
            }
        }
        // 라벨로 못 가렸으면 발견 순서대로 채운다.
        if result.fiveHour == nil, result.weekly == nil {
            if windows.indices.contains(0) { result.fiveHour = windows[0].window }
            if windows.indices.contains(1) { result.weekly = windows[1].window }
        }
        return result
    }

    private static func walk(_ node: Any, label: String,
                             into acc: inout [(label: String, window: UsageWindow)]) {
        if let dict = node as? [String: Any] {
            if let w = windowFrom(dict) { acc.append((label, w)) }
            for (k, v) in dict { walk(v, label: k, into: &acc) }
        } else if let arr = node as? [Any] {
            for (i, v) in arr.enumerated() { walk(v, label: "\(label)[\(i)]", into: &acc) }
        }
    }

    private static func windowFrom(_ dict: [String: Any]) -> UsageWindow? {
        let keys = Set(dict.keys.map { $0.lowercased() })
        let signals = ["remaining", "utilization", "used", "limit",
                       "resets_at", "resetsat", "reset_at"]
        guard signals.contains(where: { keys.contains($0) }) else { return nil }

        var w = UsageWindow()
        for (k, v) in dict {
            let lk = k.lowercased()
            if lk.contains("remaining") { w.remaining = number(v) }
            else if lk.contains("utiliz") {
                // claude.ai: utilization 은 0~100 퍼센트.
                if let u = number(v) { w.used = u; w.limit = 100 }
            }
            else if lk.contains("used") { w.used = number(v) }
            else if lk.contains("limit") || lk.contains("total") || lk.contains("cap") { w.limit = number(v) }
            else if lk.contains("reset") { w.resetsAt = date(v) }
        }
        return (w.usedFraction != nil || w.resetsAt != nil) ? w : nil
    }

    private static func number(_ v: Any) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s) }
        return nil
    }

    private static func date(_ v: Any) -> Date? {
        if let s = v as? String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: s) { return d }
            f.formatOptions = [.withInternetDateTime]
            if let d = f.date(from: s) { return d }
            // 마이크로초(6자리) 등 변종 → 소수부를 잘라내고 재시도.
            // 예: 2026-06-03T16:20:00.517675+00:00 -> 2026-06-03T16:20:00+00:00
            if let dot = s.firstIndex(of: "."),
               let tz = s[dot...].firstIndex(where: { $0 == "+" || $0 == "Z" || $0 == "-" }) {
                let trimmed = String(s[..<dot]) + String(s[tz...])
                if let d = f.date(from: trimmed) { return d }
            }
        }
        if let n = number(v) {
            return Date(timeIntervalSince1970: n > 1_000_000_000_000 ? n / 1000 : n)
        }
        return nil
    }

    private static func pretty(_ data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data),
           let p = try? JSONSerialization.data(withJSONObject: obj,
                                               options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: p, encoding: .utf8) {
            return s
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
