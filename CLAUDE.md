# CrossPromoKit

Swift package that cross-promotes your other iOS apps from a remote JSON catalog:
a drop-in SwiftUI `MoreAppsView` list and a dismissible home-screen `CrossPromoCard`,
both opening the App Store via SKOverlay. The same catalog also drives `legalNotice`,
a one-time alert when the host's terms of use or privacy policy changed, and `survey`,
a one-question ask-once dialog (host supplies question, choices and where the answer goes).

Purpose: let a developer with several apps route users between them without
rebuilding a promo screen per app — updating the catalog replaces redeploying the
apps. For indie developers and small teams; ad networks, revenue sharing and
tracking are non-goals.

Swift 6 strict concurrency, iOS 17+, no third-party dependencies.

## Commands

`swift build` / `swift test` **fail** — the package is iOS-only and its SwiftUI /
StoreKit code cannot compile for the macOS host. Always use a simulator:

```bash
xcodebuild test -scheme CrossPromoKit -destination 'platform=iOS Simulator,name=iPhone 17'
swiftlint lint --strict   # version must match .swiftlint-version; CI fails on any warning
```

Touching `Example/`? Build the demo too — it is what proves isolation and SwiftUI
overload resolution:

```bash
xcodebuild build -project Example/CrossPromoDemo/CrossPromoDemo.xcodeproj \
  -scheme CrossPromoDemo -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

## Principles

**Concurrency.** `PromoService` and `PromoEventDelegate` are `@MainActor`;
`NetworkClient` and `CacheManager` are actors. Never silence a warning with
`@unchecked Sendable` — fix the isolation.

**Offline-first.** A failed fetch falls back to cache, even stale cache. Never
block rendering or raise a dialog because the network failed.

**No hardcoded surfaces.** User-facing strings go through `L10n` /
`Localizable.xcstrings` (en/ko/ja/ar/de/es/th). Colors, spacing, and fonts come from
`WarmEmbraceTokens`.

**No new dependencies.** System frameworks only; adding one needs justification
in the PR.

**SwiftUI + `@Observable`.** Never `ObservableObject` / `@Published`.

**Tests are Swift Testing** (`@Test` / `@Suite`), never XCTest. Never assert on
wall-clock durations. If a test passes against deliberately broken code, it is
not a test.

**Privacy manifest stays true.** `Resources/PrivacyInfo.xcprivacy` declares no
tracking, no collected data and UserDefaults `CA92.1` (cache, `CrossPromoKit.card.*`,
`CrossPromoKit.legal.*`, `CrossPromoKit.survey.*` — a handled flag only, never the answer). A change that adds a
required-reason API, stores or sends data, or contacts a new host updates the
manifest and both READMEs' Privacy section in the same PR.

**Public API is documented API.** Public types and methods carry doc comments,
and a public change updates both READMEs together.

## Workflow

Issue → branch → PR → green CI → merge. `/ship` runs that pipeline end to end;
`.claude/agents/issue-worker.md` is the per-issue contract.

Releases are SemVer tags (`1.0.0`, no `v` prefix) with English release notes on
GitHub Releases; tagging is the owner's call. Host apps pin a revision or version, so
a merge reaches an app only when the app bumps its dependency.

`docs/specs/` is a historical record, not a spec to follow — parts of it describe APIs
that no longer exist. Code cites it only via `FR-###`.

## Decided against

Closed issues don't tell "won't do" from "later", so the decisions live here.
Don't re-propose without new information.

- **`.refreshable` / service-injecting initializer** — the `forceRefresh: Binding<Bool>`
  toggle covers it without widening the public API (#6, PR #16, PR #46). Either can be
  added later as a pure addition.
- **Timeout/retry policy on `PromoConfig`** — `NetworkClient(urlSession:)` is already
  the knob; retries entangle with the offline fallback (#33, PR #43).
- **Cache key migration** — the old global key can't be attributed to a URL, so the
  first launch after the per-URL split takes one cache miss (#7, PR #21).
- **Caching the SwiftLint binary in CI** — the download is under a second, cheaper than
  an `actions/cache` round trip (PR #27).
- **`file_header` lint rule** — no header convention; LICENSE carries the copyright (PR #23).
- **Consent records / events for `legalNotice`** — it is a notice: versions seen stay in
  UserDefaults, nothing is sent and no `PromoEvent` is emitted. Host policies describe
  CrossPromoKit events as promo impressions and taps only.
- **Built-in analytics** — events go to `PromoEventDelegate` only; choosing an analytics
  tool is the host app's job.
