import Foundation

/// Tracks which legal-document versions the user has been told about, so a host
/// app can announce a changed terms of use or privacy policy exactly once.
///
/// Versions come from the catalog's `legal` object, keyed by the host's
/// ``PromoConfig/currentAppID``. Two marks are kept per document in
/// `UserDefaults` under `CrossPromoKit.legal.*`:
///
/// - **notified** — the version the launch alert was last raised for. Drives ``pending``.
/// - **read** — the version the user last opened. Drives ``isUnread(_:)``, for an
///   "Updated" badge on a settings row that outlives a dismissed alert.
///
/// The first version ever seen is recorded as both, so a new install — or the
/// first launch after adopting this API — announces nothing. This is a notice,
/// not a consent record: nothing is sent anywhere.
///
/// Attach the `legalNotice(config:termsURL:privacyURL:isEnabled:)` view modifier to
/// the host's root screen for the stock alert, or read ``pending`` and call
/// ``acknowledge()`` to present your own.
@MainActor
@Observable
public final class LegalNotice {
    /// Process-wide instance used by the `legalNotice` modifier.
    public static let shared = LegalNotice()

    /// Localized "Updated" — badge text or VoiceOver value for a settings row
    /// whose document ``isUnread(_:)``.
    public static var updatedLabel: String { L10n.legalUpdated }

    /// Service loading the catalog, set by ``start(config:)``.
    private(set) var service: PromoService?

    private var versions: LegalVersions?
    private var notified: [String: String]
    private var read: [String: String]

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let notified = "CrossPromoKit.legal.notified"
        static let read = "CrossPromoKit.legal.read"
    }

    /// - Parameter defaults: Storage for the two marks.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        notified = defaults.dictionary(forKey: Key.notified) as? [String: String] ?? [:]
        read = defaults.dictionary(forKey: Key.read) as? [String: String] ?? [:]
    }

    // MARK: - Public

    /// Documents whose current version is newer than the one last announced.
    public var pending: [LegalDocument] {
        LegalDocument.allCases.filter { isNewer($0, than: notified) }
    }

    /// Whether `document` changed since the user last opened it.
    public func isUnread(_ document: LegalDocument) -> Bool {
        isNewer(document, than: read)
    }

    /// Records that every ``pending`` document was announced. They stay
    /// ``isUnread(_:)`` until opened.
    public func acknowledge() {
        for document in pending {
            notified[document.rawValue] = versions?.version(of: document)
        }
        persist()
    }

    /// Records that the user opened `document`: it is no longer pending or unread.
    public func markRead(_ document: LegalDocument) {
        guard let version = versions?.version(of: document) else { return }
        notified[document.rawValue] = version
        read[document.rawValue] = version
        persist()
    }

    // MARK: - Internal

    /// Starts loading the catalog for `config`, sharing the card's service so a
    /// launch makes at most one catalog request.
    func start(config: PromoConfig) {
        service = CrossPromoCardScheduler.shared.load(config: config)
    }

    /// Takes the versions from a loaded catalog. `nil` (no catalog yet, or no
    /// entry for this app) keeps the previous state.
    func update(_ versions: LegalVersions?) {
        guard let versions else { return }
        for document in LegalDocument.allCases {
            guard let version = versions.version(of: document), notified[document.rawValue] == nil else { continue }
            // First sighting is the baseline, not news.
            notified[document.rawValue] = version
            read[document.rawValue] = version
        }
        self.versions = versions
        persist()
    }

    // MARK: - Private

    private func isNewer(_ document: LegalDocument, than seen: [String: String]) -> Bool {
        guard let version = versions?.version(of: document), let last = seen[document.rawValue] else { return false }
        return version > last
    }

    private func persist() {
        defaults.set(notified, forKey: Key.notified)
        defaults.set(read, forKey: Key.read)
    }
}
