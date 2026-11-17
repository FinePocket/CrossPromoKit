@testable import CrossPromoKit
import Foundation
import Testing

/// Mutable clock shared between a test and the scheduler it drives.
@MainActor
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)

    func advance(days: Double) {
        now = now.addingTimeInterval(days * 86_400)
    }
}

@Suite("CrossPromoCardScheduler")
@MainActor
struct CrossPromoCardSchedulerTests {
    private let defaults = IsolatedDefaults()
    private let clock = TestClock()
    private let apps = ["finebill", "whospoke", "blurfy"].map { Fixture.app(id: $0) }
    private let rules = CardRules()

    private func scheduler(installed: Set<String> = []) -> CrossPromoCardScheduler {
        let clock = clock
        return CrossPromoCardScheduler(
            defaults: defaults.make(),
            now: { clock.now },
            isInstalled: { installed.contains($0) }
        )
    }

    /// A scheduler past the launch threshold, as on a fifth launch.
    private func eligibleScheduler(installed: Set<String> = []) -> CrossPromoCardScheduler {
        let scheduler = scheduler(installed: installed)
        for _ in 0..<rules.minLaunches { scheduler.recordLaunch() }
        return scheduler
    }

    @Test("No card before the launch or day threshold")
    func notEligibleEarly() {
        let scheduler = scheduler()
        for _ in 0..<(rules.minLaunches - 1) { scheduler.recordLaunch() }

        #expect(scheduler.card(from: apps, rules: rules) == nil)
    }

    @Test("Eligible after enough launches")
    func eligibleByLaunches() {
        #expect(eligibleScheduler().card(from: apps, rules: rules)?.id == "finebill")
    }

    @Test("Eligible after enough days even with few launches")
    func eligibleByDays() {
        let scheduler = scheduler()
        scheduler.recordLaunch()
        clock.advance(days: Double(rules.minDaysSinceInstall))

        #expect(scheduler.card(from: apps, rules: rules) != nil)
    }

    @Test("Disabled or missing rules never show a card")
    func disabled() {
        let scheduler = eligibleScheduler()

        #expect(scheduler.card(from: apps, rules: CardRules(enabled: false)) == nil)
        #expect(scheduler.card(from: apps, rules: nil) == nil)
    }

    @Test("A session keeps showing the app it first showed")
    func sessionKeepsPick() throws {
        let scheduler = eligibleScheduler()
        let first = try #require(scheduler.card(from: apps, rules: rules))
        scheduler.markShown(first)
        clock.advance(days: 1)

        #expect(scheduler.card(from: apps, rules: rules) == first)
    }

    @Test("A new session waits intervalDays, then rotates to the next app")
    func intervalAndRotation() throws {
        let first = eligibleScheduler()
        let shown = try #require(first.card(from: apps, rules: rules))
        first.markShown(shown)

        clock.advance(days: Double(rules.intervalDays) - 1)
        #expect(scheduler().card(from: apps, rules: rules) == nil)

        clock.advance(days: 1)
        #expect(scheduler().card(from: apps, rules: rules)?.id == "whospoke")
    }

    @Test("Rotation wraps around to the start of the catalog")
    func rotationWraps() {
        let scheduler = eligibleScheduler()
        scheduler.markShown(apps[2])
        clock.advance(days: Double(rules.intervalDays))

        #expect(self.scheduler().card(from: apps, rules: rules)?.id == "finebill")
    }

    @Test("Closing hides the card for the session and the app for dismissDays")
    func dismissHidesForDismissDays() throws {
        let scheduler = eligibleScheduler()
        let app = try #require(scheduler.card(from: apps, rules: rules))
        scheduler.markShown(app)
        scheduler.dismiss(app, rules: rules)
        #expect(scheduler.card(from: apps, rules: rules) == nil)

        clock.advance(days: Double(rules.intervalDays))
        let next = self.scheduler().card(from: [app], rules: rules)
        #expect(next == nil)

        clock.advance(days: Double(rules.dismissDays))
        #expect(self.scheduler().card(from: [app], rules: rules) == app)
    }

    @Test("Apps whose URL scheme opens are treated as installed")
    func skipsInstalledApps() {
        let apps = [
            Fixture.app(id: "finebill", urlScheme: "finebill"),
            Fixture.app(id: "whospoke", urlScheme: "whospoke")
        ]
        let scheduler = eligibleScheduler(installed: ["finebill"])

        #expect(scheduler.card(from: apps, rules: rules)?.id == "whospoke")
        #expect(eligibleScheduler(installed: ["finebill", "whospoke"]).card(from: apps, rules: rules) == nil)
    }
}

@Suite("Card catalog decoding")
struct CardCatalogDecodingTests {
    @Test("A catalog without card fields still decodes, with the card off")
    func decodesLegacyCatalog() throws {
        let json = Data(#"""
        {"apps":[{"id":"a","name":"A","appStoreID":"1","iconURL":"https://example.com/a.png",
        "category":"Finance","tagline":{"en":"Hi"}}]}
        """#.utf8)
        let catalog = try JSONDecoder().decode(AppCatalog.self, from: json)

        #expect(catalog.card == nil)
        #expect(catalog.providerToken == nil)
        #expect(catalog.apps.first?.urlScheme == nil)
    }

    @Test("Card rules, provider token and URL scheme decode; missing rule keys take defaults")
    func decodesCardFields() throws {
        let json = Data(#"""
        {"apps":[{"id":"a","name":"A","appStoreID":"1","iconURL":"https://example.com/a.png",
        "category":"Finance","tagline":{"en":"Hi","th":"สวัสดี"},"urlScheme":"finebill"}],
        "card":{"enabled":true,"intervalDays":14},"providerToken":"576902"}
        """#.utf8)
        let catalog = try JSONDecoder().decode(AppCatalog.self, from: json)

        #expect(catalog.card == CardRules(intervalDays: 14))
        #expect(catalog.providerToken == "576902")
        #expect(catalog.apps.first?.urlScheme == "finebill")
        #expect(catalog.apps.first?.tagline.th == "สวัสดี")
    }

    @Test("A malformed card block turns the card off instead of failing the catalog")
    func malformedCardIsIgnored() throws {
        let json = Data(#"""
        {"apps":[],"card":"yes"}
        """#.utf8)

        #expect(try JSONDecoder().decode(AppCatalog.self, from: json).card == nil)
    }
}

@Suite("PromoService card taps")
@MainActor
struct PromoServiceCardTapTests {
    @Test("A card tap presents the overlay with the card campaign and emits a tap")
    func cardTapCarriesCampaign() {
        let presenter = StubOverlayPresenter()
        let service = PromoService(
            config: PromoConfig(
                jsonURL: URL(string: "https://example.com/apps.json")!,
                currentAppID: "app.finepocket.FineBill"
            ),
            overlayPresenter: presenter
        )
        let delegate = RecordingEventDelegate()
        service.eventDelegate = delegate

        service.handleCardTap(Fixture.app(id: "blurfy", appStoreID: "111"))

        let campaign = AppStoreCampaign(campaignToken: "cross-card-finebill", providerToken: nil)
        #expect(presenter.calls == [.dismiss, .present(appStoreID: "111", campaign: campaign)])
        #expect(delegate.events == [.tap(appID: "blurfy")])
    }

    @Test("The App Store fallback URL carries ct and pt")
    func fallbackURLCarriesCampaign() {
        let url = PromoService.appStoreURL(
            appStoreID: "111",
            campaign: AppStoreCampaign(campaignToken: "cross-card-finebill", providerToken: "576902")
        )

        #expect(url?.absoluteString == "https://apps.apple.com/app/id111?ct=cross-card-finebill&pt=576902")
    }
}
