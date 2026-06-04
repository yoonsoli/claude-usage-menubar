import SwiftUI

/// Claude 시그니처 코랄(테라코타) 포인트 컬러.
private let claudeCoral = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
private let warnColor = Color(red: 0xE5 / 255, green: 0x48 / 255, blue: 0x3C / 255)

/// 메뉴바 아이콘 클릭 시 펼쳐지는 Liquid Glass 패널.
struct UsagePanel: View {
    @EnvironmentObject var monitor: UsageMonitor
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showSettings {
                SettingsView(monitor: monitor) { showSettings = false }
            } else {
                header

                if let usage = monitor.usage {
                    GlassEffectContainer(spacing: 14) {
                        HStack(spacing: 14) {
                            GaugeCard(title: "5시간", window: usage.fiveHour)
                            GaugeCard(title: "주간", window: usage.weekly)
                        }
                    }
                    Text("⚠︎ 비공식 추정치 · \(monitor.status)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.tail)
                } else {
                    placeholder
                }

                Divider().opacity(0.4)
                footer
            }
        }
        .padding(18)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 8) {
            ClaudeMark().frame(width: 16, height: 16)
            Text("Claude 사용량").font(.headline)
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
        }
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            if monitor.needsLogin {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.largeTitle).foregroundStyle(claudeCoral)
                Text("로그인 창에서 Claude에 로그인해 주세요.")
                    .font(.callout).multilineTextAlignment(.center)
            } else {
                ProgressView()
                Text("사용량을 가져오는 중…").font(.callout).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                monitor.refresh()
            } label: {
                Label("새로고침", systemImage: "arrow.clockwise")
            }
            if monitor.needsLogin || monitor.usage == nil {
                Button {
                    monitor.showLogin()
                } label: {
                    Label("로그인", systemImage: "person.crop.circle")
                }
            }
            Spacer()
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("종료", systemImage: "power")
            }
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }
}

/// 원형 게이지 카드 — 잔량을 코랄 링으로 표시. 잔량이 적으면 경고색으로 전환.
struct GaugeCard: View {
    let title: String
    let window: UsageWindow?

    var body: some View {
        VStack(spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold))

            ZStack {
                Circle().stroke(.secondary.opacity(0.16), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: used)
                    .stroke(ringColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: used)
                VStack(spacing: 0) {
                    Text(usedText).font(.title2.weight(.bold)).monospacedDigit()
                    Text("사용").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)

            VStack(spacing: 1) {
                Text(resetAbsolute).font(.caption2.weight(.medium)).monospacedDigit()
                Text(resetRelative).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .frame(height: 28)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var used: CGFloat { CGFloat(window?.usedFraction ?? 0) }

    private var ringColor: Color {
        guard let f = window?.usedFraction else { return claudeCoral }
        return f > 0.85 ? warnColor : claudeCoral
    }

    private var usedText: String {
        guard let f = window?.usedFraction else { return "—" }
        return "\(Int((f * 100).rounded()))%"
    }

    private var resetAbsolute: String {
        guard let reset = window?.resetsAt else { return " " }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d a h:mm"
        return f.string(from: reset) + " 초기화"
    }

    private var resetRelative: String {
        guard let reset = window?.resetsAt else { return " " }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short
        rel.locale = Locale(identifier: "ko_KR")
        return rel.localizedString(for: reset, relativeTo: .now)
    }
}
