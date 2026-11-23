import Foundation
import UIKit

/// Decides which app, if any, the ``CrossPromoCard`` shows right now.
///
/// Counters live in `UserDefaults` under `CrossPromoKit.card.*` so the cadence
/// survives relaunches; the session pick lives in memory so one launch keeps
/// showing the same card wherever it is embedded.
@MainActor
@Observable
final class CrossPromoCardScheduler {
    /// Process-wide instance used by ``CrossPromoCard``.
    static let shared = CrossPromoCardScheduler()

    /// Service loading the catalog for the card, created by ``load(config:)``.
    private(set) var service: PromoService?

    /// App chosen for this session, once the card has actually appeared.
    private(set) var sessionPickID: String?
    /// Set when the user closes the card, so it stays gone for the session.
    private(set) var sessionDismissed = false

    private let defaults: UserDefaults
    private let now: () -> Date
    private let isInstalled: @MainActor (String) -> Bool

    private enum Key {
        static let launchCount = "CrossPromoKit.card.launchCount"
        static let firstLaunch = "CrossPromoKit.card.firstLaunch"
        static let lastShownAt = "CrossPromoKit.card.lastShownAt"
        static let lastShownAppID = "CrossPromoKit.card.lastShownAppID"
        static let dismissedUntil = "CrossPromoKit.card.dismissedUntil"
    }

    /// - Parameters:
    ///   - defaults: Storage for the counters.
    ///   - now: Clock, injectable for tests.
    ///   - isInstalled: Whether an app registering the given URL scheme is
    ///     installed. Defaults to `canOpenURL("<scheme>://")`.
    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        isInstalled: @escaping @MainActor (String) -> Bool = CrossPromoCardScheduler.canOpen(scheme:)
    ) {
        self.defaults = defaults
        self.now = now
        self.isInstalled = isInstalled
    }

    // MARK: - Launch

    /// Counts one host-app launch and remembers the first one.
    func recordLaunch() {
        defaults.set(defaults.integer(forKey: Key.launchCount) + 1, forKey: Key.launchCount)
        if defaults.object(forKey: Key.firstLaunch) == nil {
            defaults.set(now(), forKey: Key.firstLaunch)
        }
    }

    /// Starts loading the catalog for `config`, reusing the service when the
    /// config is unchanged.
    /// - Returns: The service doing the load, shared with ``LegalNotice``.
    @discardableResult
    func load(config: PromoConfig) -> PromoService {
        let service: PromoService
        if let current = self.service, serviceConfig == config {
            service = current
        } else {
            service = PromoService(config: config)
            self.service = service
            serviceConfig = config
        }
        Task { await service.loadApps() }
        return service
    }

    @ObservationIgnored private var serviceConfig: PromoConfig?

    // MARK: - Selection

    /// The app the card should show for the loaded catalog, or `nil`.
    var currentCard: PromoApp? {
        guard let service else { return nil }
        return card(from: service.apps, rules: service.cardRules)
    }

    /// Picks the card for `apps` under `rules` without recording anything.
    ///
    /// Within a session the first app shown keeps showing; a new session shows a
    /// card only once `intervalDays` have passed since the last one.
    func card(from apps: [PromoApp], rules: CardRules?) -> PromoApp? {
        guard let rules, rules.enabled, !sessionDismissed else { return nil }
        if let sessionPickID {
            return apps.first { $0.id == sessionPickID }
        }
        guard isEligible(rules), intervalElapsed(rules) else { return nil }

        let start = apps.firstIndex { $0.id == lastShownAppID }.map { $0 + 1 } ?? 0
        let rotated = apps[start...] + apps[..<start]
        return rotated.first { isCandidate($0) }
    }

    /// Records that `app`'s card actually appeared, starting the session pick.
    func markShown(_ app: PromoApp) {
        guard sessionPickID == nil else { return }
        sessionPickID = app.id
        defaults.set(now(), forKey: Key.lastShownAt)
        defaults.set(app.id, forKey: Key.lastShownAppID)
    }

    /// Hides `app` for `rules.dismissDays` and drops the card for this session.
    func dismiss(_ app: PromoApp, rules: CardRules?) {
        let days = rules?.dismissDays ?? CardRules().dismissDays
        var until = defaults.dictionary(forKey: Key.dismissedUntil) as? [String: Double] ?? [:]
        until[app.id] = now().addingTimeInterval(Self.seconds(days: days)).timeIntervalSince1970
        defaults.set(until, forKey: Key.dismissedUntil)
        sessionPickID = nil
        sessionDismissed = true
    }

    // MARK: - Private

    private var lastShownAppID: String? { defaults.string(forKey: Key.lastShownAppID) }

    private func isEligible(_ rules: CardRules) -> Bool {
        if defaults.integer(forKey: Key.launchCount) >= rules.minLaunches { return true }
        guard let first = defaults.object(forKey: Key.firstLaunch) as? Date else { return false }
        return now().timeIntervalSince(first) >= Self.seconds(days: rules.minDaysSinceInstall)
    }

    private func intervalElapsed(_ rules: CardRules) -> Bool {
        guard let last = defaults.object(forKey: Key.lastShownAt) as? Date else { return true }
        return now().timeIntervalSince(last) >= Self.seconds(days: rules.intervalDays)
    }

    private func isCandidate(_ app: PromoApp) -> Bool {
        let until = defaults.dictionary(forKey: Key.dismissedUntil) as? [String: Double] ?? [:]
        if let hiddenUntil = until[app.id], now().timeIntervalSince1970 < hiddenUntil { return false }
        if let scheme = app.urlScheme, isInstalled(scheme) { return false }
        return true
    }

    private static func seconds(days: Int) -> TimeInterval { TimeInterval(days) * 86_400 }

    static func canOpen(scheme: String) -> Bool {
        guard let url = URL(string: "\(scheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}
