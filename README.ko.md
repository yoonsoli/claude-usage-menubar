<div align="center">

# Claude Usage Menubar

**Claude 구독 사용량(5시간·주간 한도)을 한눈에 보여주는 macOS 메뉴바 앱 & 데스크톱 위젯.**

네이티브 **Liquid Glass** 디자인과 Claude 시그니처 코랄 컬러로 만들었습니다.

![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.2-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue)
![Languages](https://img.shields.io/badge/i18n-English%20%C2%B7%20%ED%95%9C%EA%B5%AD%EC%96%B4-success)

[English](README.md) · **한국어**

<!-- 스크린샷을 docs/ 에 추가한 뒤 아래 줄의 주석을 풀어주세요 -->
<!-- <img src="docs/screenshot.png" width="420" alt="Claude Usage 메뉴바 패널"> -->

</div>

---

> [!WARNING]
> 비공식 개인 프로젝트입니다. **Anthropic과 무관합니다.** claude.ai의 내부 엔드포인트에
> 의존하므로 언제든 동작이 바뀌거나 멈출 수 있습니다.

## 기능

- 🧭 **메뉴바** — 아이콘 옆에 5시간 사용량 %를 실시간 표시, 클릭하면 Liquid Glass 패널로 5시간·주간 게이지 확인
- 🟧 **데스크톱 위젯** — `systemSmall` WidgetKit 위젯을 데스크톱·알림센터에 배치
- 🔔 **세션 알림** — 5시간 세션이 초기화되기 30분 전 알림(켜고 끌 수 있음)
- 🌐 **다국어** — 영어(기본)·한국어, 설정에서 전환
- 🚀 **로그인 시 자동 실행** — macOS 로그인 항목으로 등록(선택)
- 🔐 **1회 로그인** — claude.ai에 한 번만 로그인하면 세션이 로컬에 유지·재사용됨

## 요구 사항

- **macOS 26 (Tahoe)** 이상 — UI가 네이티브 Liquid Glass API를 사용합니다
- 빌드 시: **Xcode 26** 툴체인(Swift 6.2)

## 설치

### 소스에서 빌드

```sh
git clone https://github.com/yoonsoli/claude-usage-menubar.git
cd claude-usage-menubar
./build_app.sh                 # 메뉴바 앱 + 위젯을 ClaudeUsage.app 번들로 빌드
open ClaudeUsage.app           # 실행 (최초 1회 claude.ai 로그인 창이 뜸)
```

계속 쓰려면 `ClaudeUsage.app`을 `/Applications`로 옮기세요.

> 아직 프리빌트 릴리스는 없습니다 — 당분간 소스에서 빌드해 주세요.

## 사용법

1. 최초 실행 시 **claude.ai 로그인 창**이 한 번 뜹니다. 로그인하면 세션이 기억됩니다.
2. 이후 메뉴바에 Claude 마크와 함께 **5시간 사용량 %**가 표시됩니다.
3. 아이콘을 클릭하면 **5시간**·**주간** 게이지와 초기화 시각이 보입니다.
4. **톱니바퀴**를 누르면 설정 — 언어, 자동 실행, 세션 알림, 로그아웃.
5. macOS 위젯 갤러리에서 **위젯**을 추가하세요(바탕화면 우클릭 → 위젯 편집, 또는 알림센터).

## 동작 방식

토큰 추정값이 아니라 Claude 앱이 보여주는 **실제 사용량**을 사용합니다.

- 숨은 `WKWebView`가 claude.ai에 붙습니다. 진짜 WebKit 엔진이라 Cloudflare를 자체 통과하고 로그인 세션을 영구 보관합니다.
- 페이지의 `fetch` / `XHR`을 후킹해 `/api/organizations/{org}/usage` 응답을 가로채 `five_hour` / `seven_day` 사용률을 읽습니다.
- 앱이 공유 **App Group** 컨테이너에 스냅샷(`usage.json`)을 저장하고, 위젯이 이를 읽습니다.

## 개인정보 / 보안

- 로그인 세션은 **사용자 본인의** `~/Library`(WebKit 데이터 스토어)에만 저장됩니다. **앱 번들에는 어떤 개인정보도 들어가지 않습니다.**
- 유일한 외부 통신 대상은 `https://claude.ai/` 입니다. **텔레메트리·애널리틱스는 없습니다.**
- 사용량 스냅샷(`usage.json`)은 소유자만 접근 가능한 App Group 컨테이너에 저장됩니다.
- App Group 엔타이틀먼트를 위해 애드혹(ad-hoc) 코드 서명되어 있습니다.

## 설정

| 설정 | 동작 |
|---|---|
| **언어** | 영어(기본)·한국어 전환 |
| **로그인 시 자동 실행** | 로그인할 때 자동으로 시작 |
| **세션 종료 30분 전 알림** | 5시간 윈도우 초기화 전 로컬 알림 |
| **로그아웃** | 저장된 claude.ai 세션을 비우고 로그인 창을 다시 표시 |

## 면책 고지

Anthropic과 무관한 독립적·비공식 도구입니다. 문서화되지 않은 claude.ai 엔드포인트에
의존하므로 예고 없이 동작을 멈출 수 있습니다. 사용에 따른 책임은 사용자에게 있습니다.

## 라이선스

[MIT](LICENSE)
