# CrossPromoKit

A lightweight Swift SDK for cross-promoting your iOS apps within your app portfolio.

**Language**: [English](README.md) | [한국어](README.ko.md)

## Overview

CrossPromoKit enables seamless cross-promotion between your iOS apps using a remote JSON catalog. It provides a ready-to-use SwiftUI list of your other apps and a dismissible home-screen card, both with native App Store integration via SKOverlay.

## Features

- **SwiftUI Native**: Drop-in `MoreAppsView` component for your settings screen
- **Home-Screen Card**: `CrossPromoCard` introduces one app at a time, with remotely tuned display rules
- **SKOverlay Integration**: In-app App Store overlay for frictionless discovery
- **Remote Configuration**: JSON-based app catalog hosted anywhere (GitHub, CDN, etc.)
- **Cache-First Loading**: A cache younger than 24 hours is served without a network request; a fetch falls back to Cache → Empty State
- **Analytics Ready**: Delegate-based event tracking for impressions and taps
- **Promo Rules**: Control which apps promote which with customizable rules
- **Localization**: Localized UI strings in 7 languages plus localized catalog taglines
- **Privacy Manifest**: Ships `PrivacyInfo.xcprivacy` — no tracking, no collected data
- **Swift 6.0**: Full strict concurrency compliance with Sendable types

## Demo

A demo app is included in the `Example/CrossPromoDemo` directory to showcase all features.

<p align="center">
  <img src="docs/images/demo-screenshot.png" width="300" alt="CrossPromoDemo Screenshot">
</p>

To run the demo:
1. Open `Example/CrossPromoDemo/CrossPromoDemo.xcodeproj`
2. Select a simulator and run

The demo includes:
- Live preview of MoreAppsView with sample apps
- UI state controls (loaded, loading, empty, error)
- Event logging for impressions and taps

## Requirements

- iOS 17.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add CrossPromoKit to your project via SPM:

```swift
dependencies: [
    .package(url: "https://github.com/FinePocket/CrossPromoKit.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → enter
`https://github.com/FinePocket/CrossPromoKit.git` and choose **Up to Next Major
Version** from `1.0.0`. Release notes are on the
[Releases](https://github.com/FinePocket/CrossPromoKit/releases) page.

## Quick Start

### 1. Host Your App Catalog

Create a JSON file and host it (e.g., GitHub raw URL):

```json
{
  "apps": [
    {
      "id": "myapp1",
      "name": "My App 1",
      "appStoreID": "123456789",
      "iconURL": "https://example.com/icon1.png",
      "category": "Productivity",
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
      "category": "Finance",
      "tagline": {
        "en": "Manage your finances",
        "ko": "재정을 관리하세요"
      }
    }
  ]
}
```

### 2. Add to Your Settings Screen

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
            // Your other settings...

            Section("More Apps") {
                MoreAppsView(config: config)
            }
        }
    }
}
```

That's it! The current app is automatically excluded from the list.

## Advanced Usage

### Analytics Integration

Track user interactions with the delegate:

```swift
class AnalyticsHandler: PromoEventDelegate {
    func promoService(_ service: PromoService, didEmit event: PromoEvent) {
        switch event {
        case .impression(let appID):
            // Track impression in your analytics
            Analytics.log("promo_impression", ["app_id": appID])
        case .tap(let appID):
            // Track tap in your analytics
            Analytics.log("promo_tap", ["app_id": appID])
        }
    }
}

// Usage
let handler = AnalyticsHandler()
MoreAppsView(config: config, eventDelegate: handler)
```

> **Retain your handler.** `PromoService.eventDelegate` is a `weak` reference, so
> the delegate must be kept alive by something else — a stored property on your
> view model or another long-lived object. A handler created as a local variable is
> deallocated as soon as that scope ends and events simply stop arriving, with no
> error.

### Promo Rules

Control which apps can promote which apps:

```json
{
  "apps": [...],
  "promoRules": {
    "myapp1": ["myapp2", "myapp3"],
    "myapp2": ["myapp1"]
  }
}
```

In this example:
- `myapp1` will only show `myapp2` and `myapp3`
- `myapp2` will only show `myapp1`
- Apps without rules show all other apps

### Home-Screen Card

`CrossPromoCard` is a single dismissible card you place inside a screen's content
— between sections of a home list, or below the result of a finished task. It
introduces one other app at a time and stays out of the way:

- shows only after `minLaunches` launches **or** `minDaysSinceInstall` days
- at most one session every `intervalDays`; within a session the same app stays
- closing it hides that app for `dismissDays`
- apps rotate in catalog order, skipping already-installed apps (see below)
- `isHidden: true` (pass it for paying users) draws nothing and counts nothing

```swift
// 1. Once per launch — counts the launch and prefetches the catalog.
@main
struct MyApp: App {
    init() {
        CrossPromoCard.recordLaunch(config: .myApp)
    }
    // ...
}

// 2. Wherever the card belongs. It renders nothing until a card is due,
//    so it leaves no empty row in a List.
CrossPromoCard(config: .myApp, isHidden: store.isPro, accent: .accentColor, eventDelegate: analytics)
```

Get opens the in-app App Store overlay tagged with the campaign token
`cross-card-<host>` (the last component of `currentAppID`, lowercased) and the
catalog's `providerToken`, so App Store Connect shows installs per host app.

The card is configured remotely by the catalog's `card` object — set
`"enabled": false` to switch it off everywhere without an app update. Without a
`card` object the card never shows.

**Skipping installed apps.** Give each app a `urlScheme` in the catalog and list
the other apps' schemes in the host's `Info.plist`; otherwise `canOpenURL` always
returns `false` and installed apps are still promoted:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>finebill</string>
    <string>whospoke</string>
</array>
```

## API Reference

### MoreAppsView

The main SwiftUI view for displaying promotable apps.

```swift
init(
    config: PromoConfig,
    eventDelegate: PromoEventDelegate? = nil,
    forceRefresh: Binding<Bool> = .constant(false)
)
```

```swift
// Basic initialization
MoreAppsView(config: config)

// With analytics
MoreAppsView(config: config, eventDelegate: handler)

// With a force-refresh binding
MoreAppsView(config: config, forceRefresh: $isRefreshing)
MoreAppsView(config: config, eventDelegate: handler, forceRefresh: $isRefreshing)
```

### PromoConfig

Configuration for the promotion service.

```swift
struct PromoConfig {
    let jsonURL: URL        // Remote JSON endpoint
    let currentAppID: String // Your app's ID (excluded from list)
}
```

### PromoService

The core service managing app loading and interactions.

```swift
@Observable
class PromoService {
    var apps: [PromoApp]      // Current filtered apps
    var isLoading: Bool       // Loading state
    var error: Error?         // Error state
    weak var eventDelegate: PromoEventDelegate? // Analytics delegate (weak — retain it yourself)
    var cardRules: CardRules? // Catalog `card` block, nil when absent
    var providerToken: String? // Catalog `providerToken`

    func loadApps() async     // Valid cache, else network, else stale cache
    func forceRefresh() async // Always reload from the network
    func handleAppTap(_ app: PromoApp)        // Trigger overlay
    func handleCardTap(_ app: PromoApp)       // Overlay tagged with the card campaign
    func handleAppImpression(_ app: PromoApp) // Track impression
    func dismissOverlay()     // Dismiss the App Store overlay this service presented
}
```

`loadApps()` is cache-first. If the cache holds an entry younger than 24 hours it
is used as-is and **no network request is made**, so re-entering the promo screen
does not re-fetch the catalog. Only a missing or expired cache goes to the
network, and that fetch falls back as before: on failure the cached catalog is
shown even when it is expired — stale promotions beat an empty list while offline
— and `error` stays `nil` whenever cached data is displayed. Only a failure with
no cache at all sets `error` and shows the empty state.

`forceRefresh()` is the cache bypass: it ignores an unexpired cache and always
fetches. The existing entry is kept so it can still serve as a fallback if that
fetch fails; a successful fetch overwrites it.

`dismissOverlay()` retires the SKOverlay this service is presenting, if any. The
overlay lives on the window scene rather than on the view, so it would otherwise
outlive the promo UI; `MoreAppsView` calls this in `onDisappear`. Calling it with
no overlay presented is a no-op.

### CacheManager

The catalog cache (UserDefaults-backed, 24-hour expiration).

```swift
actor CacheManager {
    init(scope: URL, userDefaults: UserDefaults = .standard)
    init(scopeIdentifier: String, userDefaults: UserDefaults = .standard)

    func expire()      // Mark stale, keep the data
    func clearCache()  // Remove the data
}
```

Cache entries are **scoped to the catalog URL** the data came from, so two
`PromoConfig` values in the same app keep independent caches instead of
overwriting each other. `PromoService` builds its own `CacheManager(scope:)` from
`config.jsonURL` by default; pass one explicitly only if you need a different
namespace or a separate `UserDefaults` suite.

#### Invalidating a cache

Three ways to make the next load go to the network, differing in what is left to
fall back on when that load fails:

| | Cached data | Next load | Fallback if the fetch fails |
|---|---|---|---|
| `CacheManager.clearCache()` | removed | network | none — empty state |
| `CacheManager.expire()` | kept | network | the stale data |
| `PromoService.forceRefresh()` | kept | network, once | the cached data |

`expire()` is what a push notification saying "the catalog changed" should
trigger: the data stays available offline, but it is no longer trusted as fresh,
so the next ordinary `loadApps()` fetches instead of short-circuiting on the
cache. `forceRefresh()` bypasses the cache for a single call without changing its
state, so a later `loadApps()` is answered from the cache again.

```swift
let cache = CacheManager(scope: config.jsonURL)
await cache.expire()  // Next loadApps() fetches; stale data survives a failure
```

### PromoEvent

Analytics events emitted by the service.

```swift
enum PromoEvent {
    case impression(appID: String) // App row appeared
    case tap(appID: String)        // User tapped row
}
```

## JSON Format

### Full Schema

```json
{
  "apps": [
    {
      "id": "string",           // Unique identifier
      "name": "string",         // Display name
      "appStoreID": "string",   // App Store numeric ID
      "iconURL": "string",      // Image URL, or sf-symbol://<symbol-name>
      "category": "string",     // Category label
      "tagline": {              // Localized descriptions
        "en": "string",
        "ko": "string"          // also ja, ar, de, es, th
      },
      "urlScheme": "string"     // Optional — skips the app on the card when installed
    }
  ],
  "promoRules": {               // Optional
    "appId": ["allowed", "app", "ids"]
  },
  "card": {                     // Optional — CrossPromoCard rules; missing keys use these defaults
    "enabled": true,
    "minLaunches": 5,
    "minDaysSinceInstall": 3,
    "intervalDays": 7,
    "dismissDays": 30
  },
  "providerToken": "string"     // Optional — App Store pt for card campaign links
}
```

### Notes

- `iconURL` takes either a remote image URL (HTTPS recommended; plain HTTP is
  subject to App Transport Security) or an `sf-symbol://<symbol-name>` URL — e.g.
  `"sf-symbol://cloud.sun.fill"` — which draws that SF Symbol locally instead of
  downloading an image. Anything that is not `sf-symbol://` is handed to
  SwiftUI's `AsyncImage`, which falls back to a placeholder icon if the image
  cannot be loaded. The `Example/CrossPromoDemo` catalog uses the SF Symbol form.
- The catalog URL itself (`PromoConfig.jsonURL`) may be `https://`, `http://`, or
  a `file://` URL, so a JSON file bundled with the app works for demos and tests.
- `tagline` falls back to English if user's locale isn't available
- Apps are displayed in JSON array order
- The current app is always excluded automatically

## Localization

Two things are localized independently:

- **Catalog content** (`tagline`) — supplied by your JSON, keyed by language code: `en` is required, `ko`, `ja`, `ar`, `de`, `es` and `th` are optional, and a missing match for the device locale falls back to English. `category` is *not* localized — it is a plain string rendered exactly as written, so showing different category text per language means serving separate catalogs.
- **Built-in UI strings** (empty states, retry/cancel buttons, the App Store overlay error alert, the home-screen card, VoiceOver labels) — shipped inside the package as a String Catalog (`Sources/CrossPromoKit/Resources/Localizable.xcstrings`), so they stay localized regardless of the host app's bundle.

Bundled UI languages: English (source), Korean, Japanese, Arabic, German, Spanish, Thai. Other locales fall back to English.

To add a language, open `Localizable.xcstrings` in Xcode, add the locale, and translate the entries — no code changes are needed.

## Privacy

The package ships a privacy manifest (`Sources/CrossPromoKit/Resources/PrivacyInfo.xcprivacy`)
that Xcode merges into your app's privacy report:

- **No tracking** and no tracking domains.
- **No collected data types.** `PromoEvent`s are handed to your `PromoEventDelegate`;
  the package stores and sends nothing itself. Whatever your analytics SDK does with
  those events belongs in your app's own manifest.
- **Required-reason API:** UserDefaults, reason `CA92.1` — the catalog cache and the
  card's counters (`CrossPromoKit.card.*`: launch count, first launch date, last shown
  app and time, per-app dismissal deadlines).

When writing your app's privacy policy, note what happens on the wire:

- `recordLaunch(config:)` and `MoreAppsView` request the catalog (`jsonURL`) only when the
  cached copy is missing or older than 24 hours; icons load from each `iconURL`. These requests carry no identifiers, but
  the device's IP address and a standard user agent reach those hosts.
- The installed-app check (`canOpenURL` on catalog `urlScheme`s) runs on the device and
  its result is never sent anywhere.
- Get opens the App Store with the campaign token `cross-card-<host>` and the catalog's
  `providerToken`; Apple attributes those installs in App Analytics.

## License

MIT License - see [LICENSE](LICENSE) for details.

---

Made with care for the iOS developer community.
