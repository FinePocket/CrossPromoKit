import Foundation

/// A one-question survey the host asks at most once.
///
/// The kit owns the ask-once flag, the shuffle and the dialog; the host owns the
/// question, the localized choice titles and where the answer goes (for example a
/// RevenueCat subscriber attribute). Nothing is sent by the kit.
public struct Survey: Sendable {
    /// One answer. `id` is what the host forwards; `title` is already localized.
    public struct Choice: Sendable, Hashable, Identifiable {
        public let id: String
        public let title: String

        public init(id: String, title: String) {
            self.id = id
            self.title = title
        }
    }

    /// Stable key for the ask-once flag, e.g. `"buyReason"`.
    public let id: String
    /// Localized question shown as the dialog title.
    public let question: String
    /// Shown in random order each time the dialog appears.
    public let choices: [Choice]
    /// Shown after the shuffled `choices`, in order — typically "Other".
    public let pinnedLast: [Choice]

    public init(id: String, question: String, choices: [Choice], pinnedLast: [Choice] = []) {
        self.id = id
        self.question = question
        self.choices = choices
        self.pinnedLast = pinnedLast
    }

    /// Whether the user has neither answered nor skipped this survey yet.
    @MainActor
    public var shouldAsk: Bool { SurveyStore.shared.shouldAsk(id) }
}

/// Ask-once flags in `UserDefaults` under `CrossPromoKit.survey.*`. Only whether
/// the survey was handled is kept, never the answer.
@MainActor
struct SurveyStore {
    static let shared = SurveyStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ id: String) -> String { "CrossPromoKit.survey.\(id)" }

    func shouldAsk(_ id: String) -> Bool { !defaults.bool(forKey: key(id)) }

    func markHandled(_ id: String) { defaults.set(true, forKey: key(id)) }
}
