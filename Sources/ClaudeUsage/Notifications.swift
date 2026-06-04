import Foundation
import UserNotifications

/// 5시간 세션이 30분 남았을 때 로컬 알림을 보낸다.
/// resets_at - 30분 시점에 시스템 알림을 예약해, 앱이 폴링하지 않아도 정확히 그 시각에 울린다.
@MainActor
enum SessionNotifier {
    static let identifier = "claude-session-30min"
    private static let lead: TimeInterval = 30 * 60   // 30분

    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 주어진 초기화 시각 기준으로 "30분 전" 알림을 (재)예약한다.
    static func schedule(resetAt: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Claude 5시간 세션"
        content.body = "세션 종료까지 30분 남았어요."
        content.sound = .default

        let fireDate = resetAt.addingTimeInterval(-lead)
        let now = Date()

        let request: UNNotificationRequest
        if fireDate > now {
            // 미래 시점 → 정확히 그 시각에 예약
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        } else if resetAt > now {
            // 이미 30분 이내 남음 → 즉시 1회 알림
            request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        } else {
            return   // 이미 초기화 지남 → 예약 불필요
        }
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
