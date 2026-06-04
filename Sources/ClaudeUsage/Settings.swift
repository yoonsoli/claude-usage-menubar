import SwiftUI
import ServiceManagement

/// 로그인 시 자동 실행(macOS 로그인 항목) 토글 헬퍼.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ on: Bool) {
        do {
            if on {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("LaunchAtLogin 설정 실패: \(error.localizedDescription)")
        }
    }
}

/// 설정 화면 — 자동 실행 + 로그아웃.
struct SettingsView: View {
    @ObservedObject var monitor: UsageMonitor
    var onBack: () -> Void
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Text("설정").font(.headline)
                Spacer()
            }

            Toggle(isOn: $launchAtLogin) {
                Text("로그인 시 자동 실행")
            }
            .toggleStyle(.switch)
            .tint(Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255))
            .onChange(of: launchAtLogin) { _, newValue in
                LaunchAtLogin.set(newValue)
            }

            Toggle(isOn: Binding(
                get: { monitor.notifyEnabled },
                set: { monitor.setNotifyEnabled($0) }
            )) {
                Text("세션 종료 30분 전 알림")
            }
            .toggleStyle(.switch)
            .tint(Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255))

            Divider().opacity(0.4)

            Button(role: .destructive) {
                monitor.logout()
                onBack()
            } label: {
                Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
