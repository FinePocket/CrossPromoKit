# CrossPromoKit

iOS 앱 포트폴리오 내 교차 프로모션을 위한 경량 Swift SDK입니다.

**언어**: [English](README.md) | [한국어](README.ko.md)

## 개요

CrossPromoKit은 원격 JSON 카탈로그를 사용하여 iOS 앱 간 원활한 교차 프로모션을 지원합니다. SKOverlay를 통한 네이티브 App Store 통합이 포함된 바로 사용 가능한 SwiftUI 뷰를 제공합니다. 이용약관이나 개인정보 처리방침이 바뀌었을 때 사용자에게 알리는 기능도 들어 있습니다.

## 주요 기능

- **SwiftUI 네이티브**: 설정 화면에 바로 삽입 가능한 `MoreAppsView` 컴포넌트
- **홈 화면 카드**: 한 번에 앱 하나를 소개하는 `CrossPromoCard`, 노출 규칙은 원격으로 조정
- **약관·방침 변경 알림**: `legalNotice`가 같은 카탈로그로 이용약관·개인정보 처리방침 변경을 한 번 알림
- **SKOverlay 통합**: 마찰 없는 앱 발견을 위한 인앱 App Store 오버레이
- **원격 구성**: GitHub, CDN 등 어디서나 호스팅 가능한 JSON 기반 앱 카탈로그
- **캐시 우선 로딩**: 24시간이 지나지 않은 캐시는 네트워크 요청 없이 그대로 사용하고, 네트워크 요청은 캐시 → 빈 상태로 폴백
- **분석 지원**: 노출 및 탭 이벤트를 위한 델리게이트 기반 이벤트 추적
- **프로모션 규칙**: 앱별 프로모션 대상을 제어하는 커스텀 규칙
- **다국어 지원**: 내장 UI 문자열 7개 언어 지역화 및 카탈로그 태그라인 지역화
- **개인정보 매니페스트**: `PrivacyInfo.xcprivacy` 포함 — 추적 없음, 수집 데이터 없음
- **Swift 6.0**: Sendable 타입으로 완전한 엄격 동시성 준수

## 데모

`Example/CrossPromoDemo` 디렉토리에 모든 기능을 보여주는 데모 앱이 포함되어 있습니다.

<p align="center">
  <img src="docs/images/demo-screenshot.png" width="300" alt="CrossPromoDemo 스크린샷">
</p>

데모 실행 방법:
1. `Example/CrossPromoDemo/CrossPromoDemo.xcodeproj` 열기
2. 시뮬레이터 선택 후 실행

데모에 포함된 기능:
- 샘플 앱이 포함된 MoreAppsView 실시간 미리보기
- UI 상태 컨트롤 (로드됨, 로딩 중, 빈 상태, 오류)
- 노출 및 탭 이벤트 로깅

## 요구 사항

- iOS 17.0+
- Swift 6.0+
- Xcode 16.0+

## 설치

### Swift Package Manager

SPM을 통해 CrossPromoKit을 프로젝트에 추가하세요:

```swift
dependencies: [
    .package(url: "https://github.com/FinePocket/CrossPromoKit.git", from: "1.0.0")
]
```

또는 Xcode에서: File → Add Package Dependencies →
`https://github.com/FinePocket/CrossPromoKit.git` 입력 후 **Up to Next Major Version**
규칙으로 `1.0.0` 선택. 릴리스 노트는
[Releases](https://github.com/FinePocket/CrossPromoKit/releases) 페이지에 있습니다.

## 빠른 시작

### 1. 앱 카탈로그 호스팅

JSON 파일을 생성하고 호스팅하세요 (예: GitHub raw URL):

```json
{
  "apps": [
    {
      "id": "myapp1",
      "name": "My App 1",
      "appStoreID": "123456789",
      "iconURL": "https://example.com/icon1.png",
      "category": "생산성",
      "tagline": {
        "en": "Your productivity companion",
        "ko": "당신의 생산성 동반자"
      }
    },
    {
      "id": "myapp2",
      "name": "My App 2",
      "appStoreID": "987654321",
      "iconURL": "https://example.com/icon2.png",
      "category": "금융",
      "tagline": {
        "en": "Manage your finances",
        "ko": "재정을 관리하세요"
      }
    }
  ]
}
```

### 2. 설정 화면에 추가

```swift
import SwiftUI
import CrossPromoKit

struct SettingsView: View {
    private let config = PromoConfig(
        jsonURL: URL(string: "https://your-domain.com/apps.json")!,
        currentAppID: "myapp1"
    )

    var body: some View {
        List {
            // 다른 설정 항목들...

            Section("더 많은 앱") {
                MoreAppsView(config: config)
            }
        }
    }
}
```

끝입니다! 현재 앱은 목록에서 자동으로 제외됩니다.

## 고급 사용법

### 분석 연동

델리게이트로 사용자 상호작용을 추적하세요:

```swift
class AnalyticsHandler: PromoEventDelegate {
    func promoService(_ service: PromoService, didEmit event: PromoEvent) {
        switch event {
        case .impression(let appID):
            // 분석 도구에 노출 이벤트 기록
            Analytics.log("promo_impression", ["app_id": appID])
        case .tap(let appID):
            // 분석 도구에 탭 이벤트 기록
            Analytics.log("promo_tap", ["app_id": appID])
        }
    }
}

// 사용법
let handler = AnalyticsHandler()
MoreAppsView(config: config, eventDelegate: handler)
```

> **핸들러를 직접 강하게 유지하세요.** `PromoService.eventDelegate`는 `weak`
> 참조이므로, 뷰 모델의 프로퍼티처럼 수명이 긴 곳에서 델리게이트를 붙잡고 있어야
> 합니다. 지역 변수로만 만든 핸들러는 스코프가 끝나는 순간 해제되고, 아무런 오류
> 없이 이벤트가 조용히 끊깁니다.

### 프로모션 규칙

어떤 앱이 어떤 앱을 프로모션할 수 있는지 제어하세요:

```json
{
  "apps": [...],
  "promoRules": {
    "myapp1": ["myapp2", "myapp3"],
    "myapp2": ["myapp1"]
  }
}
```

이 예시에서:
- `myapp1`은 `myapp2`와 `myapp3`만 표시
- `myapp2`는 `myapp1`만 표시
- 규칙이 없는 앱은 모든 다른 앱을 표시

### 홈 화면 카드

`CrossPromoCard`는 화면 콘텐츠 안에 넣는 닫을 수 있는 카드 한 장입니다. 홈 목록의
섹션 사이나 작업을 마친 결과 아래에 둡니다. 한 번에 다른 앱 하나만 소개하고 방해하지
않도록 동작합니다:

- 실행 `minLaunches`회째 **또는** 첫 실행 후 `minDaysSinceInstall`일이 지나야 보입니다
- `intervalDays`마다 많아야 한 세션만 보이고, 한 세션 안에서는 같은 앱이 유지됩니다
- 닫으면 그 앱은 `dismissDays` 동안 숨겨집니다
- 카탈로그 순서로 번갈아 고르며 이미 설치한 앱은 건너뜁니다(아래 참고)
- `isHidden: true`(결제 사용자에게 넘기세요)면 아무것도 그리지 않고 노출도 세지 않습니다

```swift
// 1. 실행마다 한 번 — 실행 횟수를 세고 카탈로그를 미리 받아 둡니다.
@main
struct MyApp: App {
    init() {
        CrossPromoCard.recordLaunch(config: .myApp)
    }
    // ...
}

// 2. 카드를 둘 자리에. 보여 줄 카드가 없으면 아무것도 그리지 않아
//    List에 빈 행이 남지 않습니다.
CrossPromoCard(config: .myApp, isHidden: store.isPro, accent: .accentColor, eventDelegate: analytics)
```

받기를 누르면 앱 안 App Store 오버레이가 캠페인 토큰 `cross-card-<호스트>`
(`currentAppID`의 마지막 구성요소를 소문자로)와 카탈로그의 `providerToken`을 달고
열리므로, App Store Connect에서 호스트 앱별 설치를 볼 수 있습니다.

카드는 카탈로그의 `card` 객체로 원격 설정합니다. `"enabled": false`면 앱 업데이트
없이 모든 앱에서 꺼집니다. `card` 객체가 없으면 카드는 보이지 않습니다.

**설치한 앱 건너뛰기.** 카탈로그의 각 앱에 `urlScheme`을 넣고, 호스트 앱
`Info.plist`에 다른 앱들의 스킴을 적어야 합니다. 적지 않으면 `canOpenURL`이 항상
`false`를 돌려줘 이미 설치한 앱도 소개됩니다:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>finebill</string>
    <string>whospoke</string>
</array>
```

### 약관·방침 변경 알림

`legalNotice`는 이용약관이나 개인정보 처리방침이 바뀌었을 때 앱 업데이트 없이
사용자에게 알립니다. 카탈로그의 `legal` 객체에 앱 ID별로 각 문서의 현재 버전을
넣고, 루트 화면에 수정자를 붙입니다:

```swift
ContentView()
    .legalNotice(
        config: .myApp,
        termsURL: URL(string: "https://example.com/terms"),
        privacyURL: URL(string: "https://example.com/privacy")
    )
```

카탈로그의 버전이 마지막으로 알린 버전보다 새로우면, 시스템 알림창이 바뀐 문서를
앱 안 Safari 화면으로 열 수 있게 안내합니다.

- 버전마다 **한 번만** 알립니다. 기기가 처음 본 버전은 기준값으로 저장하므로 새로
  설치했거나 이 API를 넣은 뒤 첫 실행에서는 아무것도 뜨지 않습니다.
- 버전은 문서를 고칠수록 오름차순으로 정렬되는 문자열이면 됩니다. ISO 날짜
  (`"2026-11-18"`)를 쓰세요. 시행일 전에 게시하면 사전 고지가 됩니다.
- 사용자가 알아야 할 변경에만 버전을 올리세요. 페이지의 오타 수정은 카탈로그를
  고칠 필요가 없습니다.
- 카드와 같은 카탈로그 로드를 쓰므로 네트워크 요청이 늘지 않습니다. 캐시가
  24시간이라 알림이 카탈로그보다 최대 하루 늦을 수 있습니다.
- `isEnabled: false`면 아무 일도 하지 않습니다. UI 테스트와 스크린샷 촬영에 넘기세요.
- 고지일 뿐 동의 기록이 아닙니다. 어디에도 전송하지 않고 `PromoEvent`도 내지 않습니다.

알림창을 닫아도 문서는 **읽지 않음**으로 남아, 설정 행에 표시를 달 수 있습니다:

```swift
Button {
    LegalNotice.shared.markRead(.terms)
    openURL(termsURL)
} label: {
    HStack {
        Text("이용약관")
        if LegalNotice.shared.isUnread(.terms) {
            Circle().fill(.tint).frame(width: 8, height: 8)
                .accessibilityLabel(LegalNotice.updatedLabel)   // "업데이트됨", 지역화됨
        }
    }
}
```

알림창 대신 직접 만든 UI를 쓰려면 `LegalNotice.shared.pending`을 읽고, 보여 준 뒤
`acknowledge()`를 부르세요.

## API 레퍼런스

### MoreAppsView

프로모션 앱을 표시하는 메인 SwiftUI 뷰입니다.

```swift
init(
    config: PromoConfig,
    eventDelegate: PromoEventDelegate? = nil,
    forceRefresh: Binding<Bool> = .constant(false)
)
```

```swift
// 기본 초기화
MoreAppsView(config: config)

// 분석 연동
MoreAppsView(config: config, eventDelegate: handler)

// 강제 새로고침 바인딩
MoreAppsView(config: config, forceRefresh: $isRefreshing)
MoreAppsView(config: config, eventDelegate: handler, forceRefresh: $isRefreshing)
```

### PromoConfig

프로모션 서비스 구성입니다.

```swift
struct PromoConfig {
    let jsonURL: URL        // 원격 JSON 엔드포인트
    let currentAppID: String // 앱의 ID (목록에서 제외됨)
}
```

### PromoService

앱 로딩과 상호작용을 관리하는 핵심 서비스입니다.

```swift
@Observable
class PromoService {
    var apps: [PromoApp]      // 현재 필터링된 앱 목록
    var isLoading: Bool       // 로딩 상태
    var error: Error?         // 오류 상태
    weak var eventDelegate: PromoEventDelegate? // 분석 델리게이트 (weak — 호출자가 유지)
    var cardRules: CardRules? // 카탈로그 `card` 객체, 없으면 nil
    var providerToken: String? // 카탈로그 `providerToken`
    var legalVersions: LegalVersions? // 카탈로그 `legal`의 `currentAppID` 항목, 없으면 nil

    func loadApps() async     // 유효한 캐시 → 네트워크 → 만료된 캐시 순
    func forceRefresh() async // 항상 네트워크에서 다시 로드
    func handleAppTap(_ app: PromoApp)        // 오버레이 표시
    func handleCardTap(_ app: PromoApp)       // 카드 캠페인 토큰을 단 오버레이
    func handleAppImpression(_ app: PromoApp) // 노출 추적
    func dismissOverlay()     // 이 서비스가 띄운 App Store 오버레이 정리
}
```

`loadApps()`는 캐시를 먼저 봅니다. 캐시가 24시간을 넘기지 않았다면 그대로
사용하고 **네트워크 요청을 보내지 않으므로**, 프로모션 화면에 다시 들어와도
카탈로그를 매번 다시 받지 않습니다. 캐시가 없거나 만료됐을 때만 네트워크로
가며, 이때의 폴백은 기존과 같습니다. 요청이 실패하면 만료된 캐시라도 보여주고
(오프라인에서는 오래된 프로모션이 빈 목록보다 낫습니다), 캐시 데이터를 보여주는
동안 `error`는 항상 `nil`입니다. 캐시조차 없는 실패에서만 `error`가 설정되고 빈
상태가 표시됩니다.

`forceRefresh()`는 캐시를 우회하는 경로입니다. 만료되지 않은 캐시를 무시하고
항상 네트워크로 갑니다. 기존 캐시는 그대로 두어 요청이 실패하면 폴백으로 쓸 수
있고, 성공한 응답이 캐시를 덮어씁니다.

`dismissOverlay()`는 이 서비스가 표시 중인 SKOverlay를 정리합니다. 오버레이는
뷰가 아니라 윈도우 씬에 붙어 있어 프로모션 UI보다 오래 남을 수 있으므로,
`MoreAppsView`는 `onDisappear`에서 이 메서드를 호출합니다. 표시 중인 오버레이가
없으면 아무 일도 하지 않습니다.

### CacheManager

카탈로그 캐시입니다 (UserDefaults 기반, 24시간 만료).

```swift
actor CacheManager {
    init(scope: URL, userDefaults: UserDefaults = .standard)
    init(scopeIdentifier: String, userDefaults: UserDefaults = .standard)

    func expire()      // 데이터는 남기고 만료 표시만
    func clearCache()  // 데이터를 삭제
}
```

캐시 항목은 데이터를 가져온 **카탈로그 URL별로 분리**됩니다. 따라서 한 앱 안에서
서로 다른 `PromoConfig`를 써도 캐시가 서로 덮어쓰지 않습니다. `PromoService`는
기본적으로 `config.jsonURL`을 스코프로 하는 `CacheManager(scope:)`를 직접
만들며, 다른 네임스페이스나 별도의 `UserDefaults` 스위트가 필요할 때만 직접
전달하면 됩니다.

#### 캐시 무효화하기

다음 로드를 네트워크로 보내는 방법은 세 가지이며, **실패했을 때 무엇이 남는지**가
다릅니다.

| | 캐시 데이터 | 다음 로드 | 실패 시 폴백 |
|---|---|---|---|
| `CacheManager.clearCache()` | 삭제 | 네트워크 | 없음 — 빈 화면 |
| `CacheManager.expire()` | 유지 | 네트워크 | 오래된 데이터 |
| `PromoService.forceRefresh()` | 유지 | 네트워크 (1회) | 캐시 데이터 |

서버에서 카탈로그를 갱신하고 푸시로 알리는 경우에 필요한 것은 `expire()`입니다.
데이터는 오프라인 폴백으로 남지만 더 이상 최신으로 취급되지 않으므로, 다음
`loadApps()`가 캐시에서 끝나지 않고 실제로 fetch합니다. `forceRefresh()`는 캐시
상태를 바꾸지 않고 한 번만 우회하므로, 이후의 `loadApps()`는 다시 캐시로
응답됩니다.

```swift
let cache = CacheManager(scope: config.jsonURL)
await cache.expire()  // 다음 loadApps()는 fetch하고, 실패하면 기존 데이터가 남는다
```

### PromoEvent

서비스에서 발생하는 분석 이벤트입니다.

```swift
enum PromoEvent {
    case impression(appID: String) // 앱 행이 화면에 표시됨
    case tap(appID: String)        // 사용자가 행을 탭함
}
```

### LegalNotice

사용자가 어느 버전의 약관·방침까지 봤는지 기록합니다. `LegalNotice.shared`를 씁니다.

```swift
@Observable
class LegalNotice {
    static let shared: LegalNotice
    static var updatedLabel: String             // 지역화된 "업데이트됨"

    var pending: [LegalDocument]                // 마지막으로 알린 뒤 바뀐 문서
    func isUnread(_ document: LegalDocument) -> Bool // 마지막으로 연 뒤 바뀌었는지
    func acknowledge()                          // pending을 알린 것으로 기록(읽지 않음은 유지)
    func markRead(_ document: LegalDocument)    // 문서 하나를 읽음으로 기록
}

enum LegalDocument { case terms, privacy }

struct LegalVersions {                          // 카탈로그 `legal`의 앱 하나 항목
    let terms: String?
    let privacy: String?
}
```

## JSON 형식

### 전체 스키마

```json
{
  "apps": [
    {
      "id": "string",           // 고유 식별자
      "name": "string",         // 표시 이름
      "appStoreID": "string",   // App Store 숫자 ID
      "iconURL": "string",      // 이미지 URL 또는 sf-symbol://<심볼 이름>
      "category": "string",     // 카테고리 라벨
      "tagline": {              // 지역화된 설명
        "en": "string",
        "ko": "string"          // ja, ar, de, es, th도 가능
      },
      "urlScheme": "string"     // 선택 — 설치돼 있으면 카드에서 건너뜀
    }
  ],
  "promoRules": {               // 선택 사항
    "appId": ["허용된", "앱", "ID들"]
  },
  "card": {                     // 선택 — CrossPromoCard 규칙, 빠진 키는 아래 기본값
    "enabled": true,
    "minLaunches": 5,
    "minDaysSinceInstall": 3,
    "intervalDays": 7,
    "dismissDays": 30
  },
  "providerToken": "string",    // 선택 — 카드 캠페인 링크용 App Store pt
  "legal": {                    // 선택 — legalNotice 버전, 앱 ID가 키
    "appId": {
      "terms": "2026-11-18",    // 선택 — 오름차순으로 정렬되는 문자열, ISO 날짜 권장
      "privacy": "2026-11-18"   // 선택
    }
  }
}
```

### 참고사항

- `iconURL`에는 원격 이미지 URL(HTTPS 권장, 일반 HTTP는 App Transport Security의
  제약을 받습니다) 또는 `sf-symbol://<심볼 이름>` URL을 넣을 수 있습니다. 예를
  들어 `"sf-symbol://cloud.sun.fill"`은 이미지를 내려받지 않고 해당 SF Symbol을
  로컬에서 그립니다. `sf-symbol://`이 아닌 값은 SwiftUI `AsyncImage`로 전달되며,
  이미지를 불러오지 못하면 플레이스홀더 아이콘으로 대체됩니다.
  `Example/CrossPromoDemo` 카탈로그가 SF Symbol 방식을 사용합니다.
- 카탈로그 URL(`PromoConfig.jsonURL`) 자체도 `https://`, `http://`, `file://`을
  지원하므로, 앱에 번들된 JSON 파일을 데모나 테스트에 그대로 쓸 수 있습니다.
- `tagline`은 사용자 로케일에 해당하는 값이 없으면 영어로 폴백됩니다
- 앱은 JSON 배열 순서대로 표시됩니다
- 현재 앱은 항상 자동으로 제외됩니다
- `legal`은 `PromoConfig.currentAppID`가 키이고 `apps`와 별개입니다. `apps`에 없는 앱도 항목을 가질 수 있습니다. 형식이 깨진 `legal`·`card` 객체는 카탈로그 전체를 실패시키지 않고 무시됩니다

## 다국어 지원

두 종류의 지역화가 서로 독립적으로 동작합니다:

- **카탈로그 콘텐츠**(`tagline`) — 직접 호스팅하는 JSON에서 제공하며, 언어 코드를
  키로 사용합니다. `en`은 필수이고 `ko`, `ja`, `ar`, `de`, `es`, `th`는 선택이며, 기기 로케일에 해당하는
  값이 없으면 영어로 폴백됩니다. `category`는 지역화 대상이 아니라 JSON에 적은
  문자열이 그대로 표시되므로, 언어별로 다르게 보여주려면 카탈로그 자체를 분리해야
  합니다.
- **내장 UI 문자열**(빈 상태 문구, 다시 시도/취소 버튼, App Store 오버레이 오류
  알림, 홈 화면 카드, 약관·방침 변경 알림창, VoiceOver 레이블) — 패키지 안에 String Catalog
  (`Sources/CrossPromoKit/Resources/Localizable.xcstrings`)로 포함되어 있어 호스트
  앱의 번들 설정과 무관하게 지역화됩니다.

기본 제공 UI 언어: 영어(소스), 한국어, 일본어, 아랍어, 독일어, 스페인어, 태국어. 그 외 로케일은 영어로 폴백됩니다.

언어를 추가하려면 Xcode에서 `Localizable.xcstrings`를 열어 로케일을 추가하고 항목을
번역하면 됩니다. 코드 변경은 필요 없습니다.

## 개인정보

패키지에는 개인정보 매니페스트(`Sources/CrossPromoKit/Resources/PrivacyInfo.xcprivacy`)가
들어 있고, Xcode가 앱의 개인정보 리포트에 합쳐 줍니다.

- **추적 없음**, 추적 도메인 없음.
- **수집 데이터 유형 없음.** `PromoEvent`는 `PromoEventDelegate`로 넘기기만 하고 패키지는
  아무것도 저장·전송하지 않습니다. 분석 SDK가 그 이벤트로 하는 일은 앱 자체 매니페스트에
  선언하세요.
- **Required Reason API:** UserDefaults, 사유 `CA92.1` — 카탈로그 캐시와 카드 카운터
  (`CrossPromoKit.card.*`: 실행 횟수, 첫 실행일, 마지막 노출 앱·시각, 앱별 닫음 기한)와 약관·방침 알림 기록
  (`CrossPromoKit.legal.*`: 마지막으로 알린 문서 버전과 마지막으로 연 문서 버전).

앱의 개인정보 처리방침을 쓸 때는 실제로 오가는 것을 참고하세요.

- `recordLaunch(config:)`, `legalNotice`, `MoreAppsView`는 캐시가 없거나 24시간이 지났을 때만
  카탈로그(`jsonURL`)를 요청하고, 아이콘은 각 `iconURL`에서 받습니다. 식별자는 담지 않지만 기기 IP와 표준
  User-Agent가 해당 호스트에 전달됩니다.
- 설치 여부 확인(카탈로그 `urlScheme`에 대한 `canOpenURL`)은 기기에서만 하고 결과를
  어디에도 보내지 않습니다.
- 받기를 누르면 캠페인 토큰 `cross-card-<호스트>`와 카탈로그의 `providerToken`을 붙여
  App Store를 엽니다. Apple이 App Analytics에서 유입을 집계합니다.
- `legalNotice`는 사용자가 알림창 버튼을 눌렀을 때만, 넘겨받은 `termsURL`·`privacyURL`을
  `SFSafariViewController`로 엽니다. 어느 버전을 보여 줬는지는 기기에만 남습니다.

## 라이선스

MIT 라이선스 - 자세한 내용은 [LICENSE](LICENSE)를 참조하세요.

---

iOS 개발자 커뮤니티를 위해 정성껏 만들었습니다.
