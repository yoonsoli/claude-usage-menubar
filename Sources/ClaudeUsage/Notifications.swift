import Foundation
import UserNotifications

/// 5시간 세션이 30분 남았을 때 로컬 알림을 보낸다.
/// resets_at - 30분 시점에 시스템 알림을 예약해, 앱이 폴링하지 않아도 정확히 그 시각에 울린다.
@MainActor
enum SessionNotifier {
    static let identifier = "claude-session-30min"
    private static let lead: TimeInterval = 30 * 60   // 30분
    /// 이미 알림을 보낸(또는 예약한) 윈도우의 resets_at(초). 윈도우당 1회만 보내기 위한 영구 가드.
    private static let notifiedKey = "notifiedResetAt"

    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 주어진 초기화 시각 기준으로 "30분 전" 알림을 1회만 예약한다.
    /// 같은 윈도우(resets_at)에 대해서는 폴링·앱 재실행과 무관하게 중복 발송하지 않는다.
    static func schedule(resetAt: Date) {
        let resetTS = resetAt.timeIntervalSince1970
        let store = UserDefaults.standard

        // 이 윈도우는 이미 처리됨(예약 or 발송) → 아무것도 하지 않는다.
        // 예약된 미래 알림은 시스템에 남아 그대로 1회 발화한다.
        if let done = store.object(forKey: notifiedKey) as? Double, abs(done - resetTS) < 1 {
            return
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let ko = Localizer.shared.language == .korean
        let content = UNMutableNotificationContent()
        content.title = ko ? "Claude 5시간 세션" : "Claude 5-hour session"
        content.body = ko ? "세션 종료까지 30분 남았어요." : "30 minutes left until your session ends."
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
            return   // 이미 초기화 지남 → 예약 불필요(가드도 찍지 않음)
        }
        center.add(request)
        // 이 윈도우는 처리 완료로 표시 → 이후 폴링/재실행에서 재발송 방지.
        store.set(resetTS, forKey: notifiedKey)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
        UserDefaults.standard.removeObject(forKey: notifiedKey)
    }
}
