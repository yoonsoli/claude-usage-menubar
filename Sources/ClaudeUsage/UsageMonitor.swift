import SwiftUI
import WebKit
import AppKit
import WidgetKit

/// 숨은 WKWebView로 claude.ai에 붙어 usage 응답을 가로채는 데이터 레이어.
/// - 진짜 WebKit이라 Cloudflare를 자체 통과하고 로그인 세션을 영구 보관한다.
/// - fetch/XHR을 후킹해 (1) 모든 /api/ URL을 수집하고 (2) usage성 응답만 파싱한다.
@MainActor
final class UsageMonitor: ObservableObject {
    static let shared = UsageMonitor()

    @Published var usage: CapturedUsage?
    @Published var seenEndpoints: [String] = []   // 탐색용: 본 /api/ 경로들
    @Published var probeURL: String = ""          // 마지막으로 찔러본 엔드포인트
    @Published var probeRaw: String = ""          // 그 원본 응답(파싱 실패해도 표시)
    @Published var needsLogin = false
    @Published var status = "초기화 중…"
    @Published var notifyEnabled = UserDefaults.standard.bool(forKey: "notify30")
    private var lastScheduledReset: Date?

    private var webView: WKWebView?
    private var window: NSWindow?
    private var coordinator: Coordinator?
    private var refreshTimer: Timer?
    private var seenSet: Set<String> = []
    private var lastUsageURL: String?
    private var started = false

    /// 메뉴바에 표시할 5시간 사용량 %.
    var menuPercent: Int? {
        guard let f = usage?.fiveHour?.usedFraction else { return nil }
        return Int((f * 100).rounded())
    }

    func start() {
        guard !started else { return }
        started = true

        if notifyEnabled { SessionNotifier.requestAuthorization() }

        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        let ucc = WKUserContentController()
        let coord = Coordinator(monitor: self)
        coordinator = coord
        ucc.add(coord, name: "usage")
        ucc.addUserScript(WKUserScript(source: Self.interceptJS,
                                       injectionTime: .atDocumentStart,
                                       forMainFrameOnly: false))
        cfg.userContentController = ucc

        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 480, height: 640), configuration: cfg)
        wv.navigationDelegate = coord
        webView = wv

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
                           styleMask: [.titled, .closable, .resizable],
                           backing: .buffered, defer: false)
        win.title = "Claude 로그인"
        win.contentView = wv
        win.isReleasedWhenClosed = false
        window = win
        parkOffscreen()

        status = "claude.ai 로딩 중…"
        wv.load(URLRequest(url: URL(string: "https://claude.ai/")!))

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        if let u = lastUsageURL {
            probe(u)
        } else {
            probeGuesses()
        }
    }

    /// 지정한 엔드포인트를 페이지 안에서 직접 호출. 401/403이면 세션 만료로 보고 재로그인 유도.
    func probe(_ url: String) {
        let js = """
        fetch('\(url)', {credentials:'include'})
          .then(function(r){
            if (r.status === 401 || r.status === 403) {
              window.webkit.messageHandlers.usage.postMessage({type:'authError'}); return null;
            }
            return r.text();
          })
          .then(function(t){
            if (t == null) return;
            try { window.webkit.messageHandlers.usage.postMessage({type:'data', url:'\(url)', body: JSON.parse(t)}); } catch(e){}
          });
        """
        webView?.evaluateJavaScript(js)
    }

    /// 위젯이 읽을 스냅샷을 저장하고 위젯 타임라인을 리로드한다.
    private func writeWidgetSnapshot() {
        guard let u = usage else { return }
        UsageSnapshot(
            fiveHourUsed: u.fiveHour?.usedFraction ?? 0,
            fiveHourReset: u.fiveHour?.resetsAt,
            weeklyUsed: u.weekly?.usedFraction ?? 0,
            weeklyReset: u.weekly?.resetsAt,
            updatedAt: .now
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 세션 30분 전 알림 켜기/끄기.
    func setNotifyEnabled(_ on: Bool) {
        notifyEnabled = on
        UserDefaults.standard.set(on, forKey: "notify30")
        if on {
            SessionNotifier.requestAuthorization()
            lastScheduledReset = nil
            updateSessionNotification()
        } else {
            SessionNotifier.cancel()
            lastScheduledReset = nil
        }
    }

    /// 현재 5시간 윈도우의 초기화 시각이 바뀌면 알림을 다시 예약한다.
    private func updateSessionNotification() {
        guard notifyEnabled, let reset = usage?.fiveHour?.resetsAt else { return }
        if reset != lastScheduledReset {
            lastScheduledReset = reset
            SessionNotifier.schedule(resetAt: reset)
        }
    }

    /// 로그아웃: 웹뷰 세션(쿠키·스토리지)을 비우고 로그인 화면으로 되돌린다.
    func logout() {
        usage = nil
        lastUsageURL = nil
        status = "로그아웃 중…"
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.removeData(ofTypes: types, modifiedSince: .distantPast) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.status = "로그아웃됨"
                self.webView?.load(URLRequest(url: URL(string: "https://claude.ai/")!))
                self.showLogin()
            }
        }
    }

    func showLogin() {
        guard let win = window else { return }
        needsLogin = true
        win.ignoresMouseEvents = false
        win.alphaValue = 1
        win.setContentSize(NSSize(width: 480, height: 640))
        win.center()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    func hideLogin() {
        needsLogin = false
        parkOffscreen()
        NSApp.setActivationPolicy(.accessory)
    }

    private func parkOffscreen() {
        guard let win = window else { return }
        win.alphaValue = 0
        win.ignoresMouseEvents = true
        win.setFrame(NSRect(x: -4000, y: -4000, width: 480, height: 640), display: false)
        win.orderFrontRegardless()
    }

    // MARK: - Coordinator 콜백 (메인 스레드)

    fileprivate func didFinishNavigation(url: URL?) {
        let s = url?.absoluteString ?? ""
        if s.contains("/login") || s.contains("/auth") || s.contains("oauth") {
            status = "로그인이 필요합니다"
            showLogin()
        } else if s.contains("claude.ai") {
            if needsLogin { hideLogin() }
            if usage == nil { status = "사용량 수집 중…" }
            // claude.ai는 홈에서 /usage를 자동 호출하지 않으므로 직접 유발한다.
            // org id가 다른 XHR로 노출될 시간을 주기 위해 잠시 뒤 호출.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.probeGuesses()
            }
        }
    }

    fileprivate func handleMessage(_ dict: [String: Any]) {
        let type = dict["type"] as? String ?? ""
        let url = dict["url"] as? String ?? ""

        if type == "authError" {
            status = "세션 만료 · 로그인 필요"
            showLogin()
            return
        }

        if type == "url" {
            let key = url.components(separatedBy: "?").first ?? url
            if !key.isEmpty, !seenSet.contains(key) {
                seenSet.insert(key)
                seenEndpoints = Array(seenSet).sorted()
            }
            return
        }

        if type == "data", let body = dict["body"],
           let data = try? JSONSerialization.data(withJSONObject: body) {
            let parsed = UsageParser.parse(jsonData: data, url: url)
            // 파싱 실패해도 탐색을 위해 원본은 항상 보여준다.
            probeURL = url
            probeRaw = parsed.rawJSON
            // 실제 윈도우를 하나라도 뽑았을 때만 게이지로 채택.
            guard parsed.fiveHour != nil || parsed.weekly != nil else { return }
            lastUsageURL = url
            usage = parsed
            let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
            status = "업데이트됨 · \(f.string(from: .now))"
            if needsLogin { hideLogin() }
            updateSessionNotification()
            writeWidgetSnapshot()
        }
    }

    /// 발견된 org 주소에서 base를 뽑아 `…/usage` 류를 추측 호출한다.
    func probeGuesses() {
        guard let sample = seenEndpoints.first(where: { $0.contains("/api/organizations/") }),
              let r = sample.range(of: #"/api/organizations/[0-9a-fA-F-]+"#, options: .regularExpression)
        else { return }
        let base = String(sample[..<r.upperBound])      // …/api/organizations/{org}
        probe(base + "/usage")
    }
}

private final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    weak var monitor: UsageMonitor?
    init(monitor: UsageMonitor) { self.monitor = monitor }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url
        MainActor.assumeIsolated { monitor?.didFinishNavigation(url: url) }
    }

    func userContentController(_ controller: WKUserContentController,
                              didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any] else { return }
        MainActor.assumeIsolated { monitor?.handleMessage(dict) }
    }
}

extension UsageMonitor {
    /// 모든 fetch/XHR을 후킹: /api/ URL은 목록으로, 강한 usage 신호가 든 응답은 본문째 전달.
    static let interceptJS = #"""
    (function () {
      function post(o) { try { window.webkit.messageHandlers.usage.postMessage(o); } catch (e) {} }
      function strong(text) {
        try {
          if (!text || text.length > 300000) return null;
          var j = JSON.parse(text);
          var s = JSON.stringify(j);
          if (/("remaining"|utilization|resets?_at|reset_at)/i.test(s)) return j;
          return null;
        } catch (e) { return null; }
      }
      function handle(url, text) {
        url = '' + url;
        if (/\/api\//.test(url)) post({ type: 'url', url: url });
        var j = strong(text);
        if (j) post({ type: 'data', url: url, body: j });
      }
      var origFetch = window.fetch;
      if (origFetch) {
        window.fetch = function () {
          var args = arguments;
          var p = origFetch.apply(this, args);
          try {
            var u = (args[0] && args[0].url) ? args[0].url : args[0];
            p.then(function (r) {
              try { r.clone().text().then(function (t) { handle(u, t); }); } catch (e) {}
            });
          } catch (e) {}
          return p;
        };
      }
      var OpenX = window.XMLHttpRequest.prototype.open;
      var SendX = window.XMLHttpRequest.prototype.send;
      window.XMLHttpRequest.prototype.open = function (m, u) { this.__usageURL = u; return OpenX.apply(this, arguments); };
      window.XMLHttpRequest.prototype.send = function () {
        var self = this;
        this.addEventListener('load', function () {
          try { handle(self.__usageURL, self.responseText); } catch (e) {}
        });
        return SendX.apply(this, arguments);
      };
    })();
    """#
}
