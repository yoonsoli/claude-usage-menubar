import SwiftUI
import AppKit

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var monitor = UsageMonitor.shared

    var body: some Scene {
        MenuBarExtra {
            UsagePanel()
                .environmentObject(monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UsageMonitor.shared.start()
    }
}

/// 메뉴바에 보이는 라벨 — Claude 마크 아이콘 + 5시간 사용량 %.
/// (메뉴바 라벨에선 Canvas가 렌더되지 않아 NSImage로 구워서 표시한다.)
struct MenuBarLabel: View {
    @ObservedObject var monitor: UsageMonitor

    var body: some View {
        Image(nsImage: MenuBarIcon.image)
        if let pct = monitor.menuPercent {
            Text("\(pct)%")
        }
    }
}

/// ClaudeMark를 메뉴바용 NSImage로 한 번 구워 캐시한다.
@MainActor
enum MenuBarIcon {
    static let image: NSImage = {
        let renderer = ImageRenderer(content: ClaudeMark().frame(width: 18, height: 18))
        renderer.scale = 2
        let img = renderer.nsImage ?? NSImage()
        img.isTemplate = false
        return img
    }()
}

/// Claude 시그니처 선버스트(방사형) 마크를 코랄색으로 그린다.
struct ClaudeMark: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let count = 11
            let inner = size.width * 0.06
            let outer = size.width * 0.46
            let lineW = size.width * 0.11
            var path = Path()
            for i in 0..<count {
                let a = (Double(i) / Double(count)) * 2 * .pi - .pi / 2
                path.move(to: CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner))
                path.addLine(to: CGPoint(x: c.x + cos(a) * outer, y: c.y + sin(a) * outer))
            }
            ctx.stroke(path,
                       with: .color(Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)),
                       style: StrokeStyle(lineWidth: lineW, lineCap: .round))
        }
    }
}
