import Foundation

/// Root entity representing the complete JSON response from the remote endpoint.
public struct AppCatalog: Codable, Sendable, Equatable {
    /// Array of promotable apps
    public let apps: [PromoApp]
    /// Maps host app ID to array of allowed promo app IDs (optional)
    public let promoRules: [String: [String]]?
    /// Rules for the home-screen ``CrossPromoCard``. `nil` means the card never shows.
    public let card: CardRules?
    /// App Store provider token (`pt`) attached to card taps so App Analytics can
    /// attribute installs to the card campaign. Optional.
    public let providerToken: String?
    /// Maps app ID to the current versions of that app's legal documents, for
    /// ``LegalNotice``. Optional.
    public let legal: [String: LegalVersions]?

    public init(
        apps: [PromoApp],
        promoRules: [String: [String]]? = nil,
        card: CardRules? = nil,
        providerToken: String? = nil,
        legal: [String: LegalVersions]? = nil
    ) {
        self.apps = apps
        self.promoRules = promoRules
        self.card = card
        self.providerToken = providerToken
        self.legal = legal
    }

    private enum CodingKeys: String, CodingKey {
        case apps, promoRules, card, providerToken, legal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apps = try container.decode([PromoApp].self, forKey: .apps)
        promoRules = try container.decodeIfPresent([String: [String]].self, forKey: .promoRules)
        // A malformed card block must not take the whole catalog (and the
        // More Apps list) down with it — it only turns the card off.
        card = try? container.decodeIfPresent(CardRules.self, forKey: .card)
        providerToken = try? container.decodeIfPresent(String.self, forKey: .providerToken)
        legal = try? container.decodeIfPresent([String: LegalVersions].self, forKey: .legal)
    }
}
