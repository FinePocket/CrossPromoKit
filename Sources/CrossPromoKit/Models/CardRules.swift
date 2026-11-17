import Foundation

/// Remote rules that decide when the home-screen ``CrossPromoCard`` may appear.
///
/// Delivered in the catalog's `card` object so the cadence can change, or the
/// card can be switched off, without an app update. Missing keys take the
/// defaults below.
public struct CardRules: Codable, Sendable, Equatable {
    /// Master switch. `false` hides the card everywhere.
    public let enabled: Bool
    /// The card may show once the host app has launched this many times…
    public let minLaunches: Int
    /// …or once this many days have passed since its first recorded launch.
    public let minDaysSinceInstall: Int
    /// Minimum days between two sessions that show a card.
    public let intervalDays: Int
    /// Days an app stays hidden after the user closes its card.
    public let dismissDays: Int

    public init(
        enabled: Bool = true,
        minLaunches: Int = 5,
        minDaysSinceInstall: Int = 3,
        intervalDays: Int = 7,
        dismissDays: Int = 30
    ) {
        self.enabled = enabled
        self.minLaunches = minLaunches
        self.minDaysSinceInstall = minDaysSinceInstall
        self.intervalDays = intervalDays
        self.dismissDays = dismissDays
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, minLaunches, minDaysSinceInstall, intervalDays, dismissDays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = CardRules()
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? defaults.enabled
        minLaunches = try container.decodeIfPresent(Int.self, forKey: .minLaunches) ?? defaults.minLaunches
        minDaysSinceInstall = try container.decodeIfPresent(Int.self, forKey: .minDaysSinceInstall)
            ?? defaults.minDaysSinceInstall
        intervalDays = try container.decodeIfPresent(Int.self, forKey: .intervalDays) ?? defaults.intervalDays
        dismissDays = try container.decodeIfPresent(Int.self, forKey: .dismissDays) ?? defaults.dismissDays
    }
}
