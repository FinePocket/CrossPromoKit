@testable import CrossPromoKit
import Foundation
import Testing

@Suite("Survey")
@MainActor
struct SurveyTests {
    private let defaults = IsolatedDefaults()

    @Test("Asks until handled, then never again — across launches")
    func asksOnce() {
        let first = SurveyStore(defaults: defaults.make())
        #expect(first.shouldAsk("buyReason"))
        #expect(first.shouldAsk("useCase"))

        first.markHandled("buyReason")

        let relaunch = SurveyStore(defaults: defaults.make())
        #expect(!relaunch.shouldAsk("buyReason"))
        #expect(relaunch.shouldAsk("useCase"))
    }

    @Test("Strings exist for the dialog")
    func strings() {
        #expect(L10n.surveySkip != "survey.skip")
        #expect(L10n.surveyOnce != "survey.once")
    }
}
