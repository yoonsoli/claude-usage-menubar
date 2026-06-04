# Claude Usage Menubar

macOS 메뉴바 앱 + 데스크톱 위젯으로 **Claude 구독 사용량**(5시간 세션 · 주간 한도)을 한눈에 봅니다.
Liquid Glass 디자인과 Claude의 코랄(#D97757) 포인트 컬러를 사용합니다.

> ⚠️ 비공식 개인 프로젝트입니다. Anthropic과 무관하며, claude.ai의 내부 엔드포인트에 의존하므로 언제든 동작하지 않을 수 있습니다.

## 기능

- **메뉴바 앱** — 아이콘 옆에 5시간 사용량 %를 표시, 클릭하면 글래스 패널로 5시간·주간 게이지 확인
- **정사각형 위젯** — `systemSmall` WidgetKit 위젯으로 데스크톱/알림센터에 배치
- **세션 종료 30분 전 알림** — 설정에서 켜고 끌 수 있음
- **설정** — 로그인 시 자동 실행 토글, 로그아웃
- **로그인** — 최초 1회 claude.ai 로그인 창이 뜨고, 이후 세션은 로컬에 유지됨

## 동작 방식

토큰 추정값이 아니라 claude.ai 앱이 보여주는 **실제 사용량**을 사용합니다.

- 숨은 `WKWebView`가 claude.ai에 붙어(진짜 WebKit이라 Cloudflare를 자체 통과) 로그인 세션을 영구 보관합니다.
- 페이지의 `fetch`/`XHR`을 후킹해 `/api/organizations/{org}/usage` 응답을 가로채 `five_hour`/`seven_day` 사용률을 읽습니다.
- 앱이 App Group 컨테이너에 스냅샷(`usage.json`)을 저장하고, 위젯이 이를 읽습니다.

## 빌드

macOS 26(Tahoe) + Xcode 26 toolchain(Swift 6.2)이 필요합니다.

```sh
./build_app.sh        # 메뉴바 앱 + 위젯 익스텐션을 ClaudeUsage.app 번들로 빌드
open ClaudeUsage.app  # 실행 (최초 1회 로그인 창이 뜸)
```

## 개인정보 / 보안

- 로그인 세션은 사용자의 `~/Library`(WebKit 데이터 스토어)에만 저장되며, 앱 번들에는 어떤 개인정보도 포함되지 않습니다.
- 유일한 외부 통신 대상은 `https://claude.ai/` 입니다. 텔레메트리·애널리틱스는 없습니다.
- 사용량 스냅샷(`usage.json`)은 소유자만 접근 가능한 App Group 컨테이너에 저장됩니다.

## 라이선스

[MIT](LICENSE)
