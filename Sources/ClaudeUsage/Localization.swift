import Foundation
import Combine
import WidgetKit

/// 앱 언어. 기본값은 영어. 설정에서 한국어로 바꿀 수 있다.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case korean = "ko"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .korean: return "한국어"
        }
    }

    var locale: Locale {
        Locale(identifier: self == .korean ? "ko_KR" : "en_US")
    }

    /// App Group에 저장된 현재 언어(앱·위젯이 공유). 기본값 영어.
    static var current: AppLanguage {
        let store = UserDefaults(suiteName: appGroup) ?? .standard
        return store.string(forKey: storageKey).flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    static let appGroup = "group.com.claudeusage.shared"
    static let storageKey = "appLanguage"
}

/// 현재 언어를 들고 있는 관측 가능한 매니저. 뷰는 `Localizer.shared`를 관찰해 즉시 갱신된다.
@MainActor
final class Localizer: ObservableObject {
    static let shared = Localizer()

    @Published private(set) var language: AppLanguage

    private static var store: UserDefaults {
        UserDefaults(suiteName: AppLanguage.appGroup) ?? .standard
    }

    private init() {
        language = Localizer.store.string(forKey: AppLanguage.storageKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    func setLanguage(_ lang: AppLanguage) {
        guard lang != language else { return }
        language = lang
        Localizer.store.set(lang.rawValue, forKey: AppLanguage.storageKey)
        WidgetCenter.shared.reloadAllTimelines()   // 위젯도 새 언어로 다시 그린다
    }

    /// 키를 현재 언어 문자열로 변환.
    func t(_ key: L) -> String { key.string(language) }
}

/// UI 문자열 키 — 언어별 문구를 한곳에서 관리한다.
enum L {
    case usageTitle, fiveHour, weekly, unofficialEstimate
    case loginPrompt, fetching, refresh, login, quit, usedLabel
    case settingsTitle, language, launchAtLogin, notify30, logout

    func string(_ lang: AppLanguage) -> String {
        let ko = lang == .korean
        switch self {
        case .usageTitle:         return ko ? "Claude 사용량" : "Claude Usage"
        case .fiveHour:           return ko ? "5시간" : "5-hour"
        case .weekly:             return ko ? "주간" : "Weekly"
        case .unofficialEstimate: return ko ? "비공식 추정치" : "Unofficial estimate"
        case .loginPrompt:        return ko ? "로그인 창에서 Claude에 로그인해 주세요."
                                            : "Please sign in to Claude in the login window."
        case .fetching:           return ko ? "사용량을 가져오는 중…" : "Fetching usage…"
        case .refresh:            return ko ? "새로고침" : "Refresh"
        case .login:              return ko ? "로그인" : "Sign In"
        case .quit:               return ko ? "종료" : "Quit"
        case .usedLabel:          return ko ? "사용" : "used"
        case .settingsTitle:      return ko ? "설정" : "Settings"
        case .language:           return ko ? "언어" : "Language"
        case .launchAtLogin:      return ko ? "로그인 시 자동 실행" : "Launch at login"
        case .notify30:           return ko ? "세션 종료 30분 전 알림"
                                            : "Notify 30 min before session ends"
        case .logout:             return ko ? "로그아웃" : "Sign Out"
        }
    }
}

/// 데이터 레이어 상태 — 표시 시점에 현재 언어로 변환한다(언어 변경 시 즉시 반영).
enum StatusKey: Equatable, Sendable {
    case initializing, loading, loggingOut, loggedOut
    case needLogin, collecting, sessionExpired
    case updated(Date)

    func string(_ lang: AppLanguage) -> String {
        let ko = lang == .korean
        switch self {
        case .initializing:   return ko ? "초기화 중…" : "Initializing…"
        case .loading:        return ko ? "claude.ai 로딩 중…" : "Loading claude.ai…"
        case .loggingOut:     return ko ? "로그아웃 중…" : "Signing out…"
        case .loggedOut:      return ko ? "로그아웃됨" : "Signed out"
        case .needLogin:      return ko ? "로그인이 필요합니다" : "Sign-in required"
        case .collecting:     return ko ? "사용량 수집 중…" : "Collecting usage…"
        case .sessionExpired: return ko ? "세션 만료 · 로그인 필요" : "Session expired · sign-in required"
        case .updated(let d):
            let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
            return "\(ko ? "업데이트됨" : "Updated") · \(f.string(from: d))"
        }
    }
}
