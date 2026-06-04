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
    @ObservedObject private var loc = Localizer.shared
    var onBack: () -> Void
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private let coral = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Text(loc.t(.settingsTitle)).font(.headline)
                Spacer()
            }

            HStack {
                Text(loc.t(.language))
                Spacer()
                Picker("", selection: Binding(
                    get: { loc.language },
                    set: { loc.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .tint(coral)
            }

            Toggle(isOn: $launchAtLogin) {
                Text(loc.t(.launchAtLogin))
            }
            .toggleStyle(.switch)
            .tint(coral)
            .onChange(of: launchAtLogin) { _, newValue in
                LaunchAtLogin.set(newValue)
            }

            Toggle(isOn: Binding(
                get: { monitor.notifyEnabled },
                set: { monitor.setNotifyEnabled($0) }
            )) {
                Text(loc.t(.notify30))
            }
            .toggleStyle(.switch)
            .tint(coral)

            Divider().opacity(0.4)

            Button(role: .destructive) {
                monitor.logout()
                onBack()
            } label: {
                Label(loc.t(.logout), systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
