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
    /// 폴링(사용량 자동 갱신)·앱 재실행, 그리고 resets_at 값이 약간 흔들리는 경우에도
    /// 한 세션 윈도우당 최대 1회만 발송한다.
    static func schedule(resetAt: Date) {
        let now = Date()
        guard resetAt > now else { return }   // 이미 초기화 지남 → 할 일 없음

        let store = UserDefaults.standard
        let resetTS = resetAt.timeIntervalSince1970
        let fireDate = resetAt.addingTimeInterval(-lead)
        let center = UNUserNotificationCenter.current()

        if fireDate > now {
            // 아직 30분 넘게 남음 → 정확한 시각에 1회 예약.
            // 미래 트리거는 즉시 울리지 않으므로, 갱신 때마다 다시 예약돼도 중복 발송이 없다.
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.add(UNNotificationRequest(identifier: identifier, content: content(), trigger: trigger))
            store.set(resetTS, forKey: notifiedKey)
        } else {
            // 이미 30분 이내 → 즉시 1회. 단, 직전에 알린 윈도우가 아직 끝나지 않았다면
            // (= 같은 세션 구간) 폴링·재실행으로 다시 들어와도 재발송하지 않는다.
            if let last = store.object(forKey: notifiedKey) as? Double, now.timeIntervalSince1970 < last {
                return
            }
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.add(UNNotificationRequest(identifier: identifier, content: content(), trigger: nil))
            store.set(resetTS, forKey: notifiedKey)
        }
    }

    private static func content() -> UNMutableNotificationContent {
        let ko = Localizer.shared.language == .korean
        let c = UNMutableNotificationContent()
        c.title = ko ? "Claude 5시간 세션" : "Claude 5-hour session"
        c.body = ko ? "세션 종료까지 30분 남았어요." : "30 minutes left until your session ends."
        c.sound = .default
        return c
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
        UserDefaults.standard.removeObject(forKey: notifiedKey)
    }
}
