<div align="center">

# Claude Usage Menubar

**A macOS menu bar app & desktop widget that shows your Claude subscription usage — 5‑hour and weekly limits — at a glance.**

Built with native **Liquid Glass** design and Claude's signature coral accent.

![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.2-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue)
![Languages](https://img.shields.io/badge/i18n-English%20%C2%B7%20%ED%95%9C%EA%B5%AD%EC%96%B4-success)

<!-- 스크린샷을 docs/ 에 추가한 뒤 아래 경로를 바꿔주세요 -->
<!-- <img src="docs/screenshot.png" width="420" alt="Claude Usage menu bar panel"> -->

</div>

---

> [!WARNING]
> Unofficial personal project. **Not affiliated with Anthropic.** It relies on
> claude.ai's internal endpoints, which can change or break at any time.

## Features

- 🧭 **Menu bar** — live 5‑hour usage % next to the icon; click to expand a Liquid Glass panel with 5‑hour and weekly gauges
- 🟧 **Desktop widget** — `systemSmall` WidgetKit widget for the desktop or Notification Center
- 🔔 **Session alerts** — optional notification 30 minutes before your 5‑hour session resets
- 🌐 **Bilingual** — English (default) and Korean, switchable in Settings
- 🚀 **Launch at login** — optional, via macOS login items
- 🔐 **One‑time sign‑in** — log in to claude.ai once; the session is kept locally and reused

## Requirements

- **macOS 26 (Tahoe)** or later — the UI uses the native Liquid Glass APIs
- To build: the **Xcode 26** toolchain (Swift 6.2)

## Installation

### Build from source

```sh
git clone https://github.com/yoonsoli/claude-usage-menubar.git
cd claude-usage-menubar
./build_app.sh                 # builds the menu bar app + widget into ClaudeUsage.app
open ClaudeUsage.app           # launch (a claude.ai login window appears once)
```

To keep it around, drag `ClaudeUsage.app` into `/Applications`.

> No prebuilt release is published yet — build from source for now.

## Usage

1. On first launch, a **claude.ai login window** appears. Sign in once; the session is remembered.
2. The menu bar then shows your **5‑hour usage %** next to the Claude mark.
3. Click the icon to open the panel with **5‑hour** and **weekly** gauges and reset times.
4. Click the **gear** to open Settings — language, launch at login, session alerts, and sign out.
5. Add the **widget** from the macOS widget gallery (desktop right‑click → Edit Widgets, or Notification Center).

## How it works

It shows the **real usage numbers** that the Claude app displays — not token estimates.

- A hidden `WKWebView` attaches to claude.ai. Because it's a real WebKit engine, it passes Cloudflare on its own and keeps the login session persistent.
- It hooks the page's `fetch` / `XHR` calls and intercepts the response from `/api/organizations/{org}/usage`, reading the `five_hour` / `seven_day` utilization.
- The app writes a snapshot (`usage.json`) into a shared **App Group** container, and the widget reads it from there.

## Privacy & Security

- The login session is stored only in **your** `~/Library` (WebKit data store). **No personal data is ever placed in the app bundle.**
- The **only** outbound connection is to `https://claude.ai/`. There is **no telemetry or analytics**.
- The usage snapshot (`usage.json`) lives in an owner‑only App Group container.
- The app is ad‑hoc code‑signed for the App Group entitlement.

## Settings

| Setting | What it does |
|---|---|
| **Language** | Switch between English (default) and Korean |
| **Launch at login** | Start automatically when you log in |
| **Notify 30 min before session ends** | Local notification before the 5‑hour window resets |
| **Sign out** | Clear the stored claude.ai session and show the login window again |

## Disclaimer

This is an independent, unofficial tool with no affiliation to Anthropic. It depends on
undocumented claude.ai endpoints and may stop working without notice. Use at your own discretion.

## License

[MIT](LICENSE)
