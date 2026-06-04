import WidgetKit
import SwiftUI

private let coral = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(UsageEntry(date: .now, snapshot: UsageSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = UsageEntry(date: .now, snapshot: UsageSnapshot.load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)
            ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// 정사각형(systemSmall) 위젯 뷰 — 5시간 사용량 링 + 주간 사용량 바.
struct ClaudeWidgetView: View {
    var entry: UsageEntry

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 4) {
                ClaudeMarkMini().frame(width: 11, height: 11)
                Text("Claude").font(.caption2.weight(.semibold))
                Spacer()
            }

            ZStack {
                Circle().stroke(.secondary.opacity(0.16), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: five)
                    .stroke(fiveColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(fiveText).font(.title2.weight(.bold)).monospacedDigit()
                    Text(ko ? "5시간" : "5-hour").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 2) {
                HStack {
                    Text(ko ? "주간" : "Weekly").font(.system(size: 9))
                    Spacer()
                    Text(weekText).font(.system(size: 9)).monospacedDigit()
                }
                .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.secondary.opacity(0.16))
                        Capsule().fill(coral).frame(width: geo.size.width * week)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Rectangle().fill(.background)
        }
    }

    private var ko: Bool { AppLanguage.current == .korean }
    private var five: CGFloat { CGFloat(entry.snapshot?.fiveHourUsed ?? 0) }
    private var week: CGFloat { CGFloat(entry.snapshot?.weeklyUsed ?? 0) }
    private var fiveColor: Color { five > 0.85 ? .red : coral }
    private var fiveText: String { entry.snapshot == nil ? "—" : "\(Int((five * 100).rounded()))%" }
    private var weekText: String { entry.snapshot == nil ? "—" : "\(Int((week * 100).rounded()))%" }
}

/// 위젯용 작은 Claude 선버스트 마크.
struct ClaudeMarkMini: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let count = 11
            let inner = size.width * 0.06
            let outer = size.width * 0.46
            var path = Path()
            for i in 0..<count {
                let a = (Double(i) / Double(count)) * 2 * .pi - .pi / 2
                path.move(to: CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner))
                path.addLine(to: CGPoint(x: c.x + cos(a) * outer, y: c.y + sin(a) * outer))
            }
            ctx.stroke(path, with: .color(coral),
                       style: StrokeStyle(lineWidth: size.width * 0.11, lineCap: .round))
        }
    }
}

@main
struct ClaudeUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaudeUsageWidget()
    }
}

struct ClaudeUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClaudeUsageWidget", provider: Provider()) { entry in
            ClaudeWidgetView(entry: entry)
        }
        .configurationDisplayName(AppLanguage.current == .korean ? "Claude 사용량" : "Claude Usage")
        .description(AppLanguage.current == .korean
            ? "5시간·주간 사용량을 한눈에"
            : "5-hour and weekly usage at a glance")
        .supportedFamilies([.systemSmall])
    }
}
