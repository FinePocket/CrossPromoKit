import SwiftUI

public extension View {
    /// Asks `survey` with a system confirmation dialog, once.
    ///
    /// The host decides *when* — set `isPresented` after checking ``Survey/shouldAsk``.
    /// Picking a choice calls `onAnswer`; "Skip" or dismissing the dialog any other
    /// way counts as a skip. Either way the survey is never asked again.
    func survey(
        _ survey: Survey,
        isPresented: Binding<Bool>,
        onAnswer: @escaping (Survey.Choice) -> Void
    ) -> some View {
        modifier(SurveyModifier(survey: survey, isPresented: isPresented, onAnswer: onAnswer))
    }
}

struct SurveyModifier: ViewModifier {
    let survey: Survey
    @Binding var isPresented: Bool
    let onAnswer: (Survey.Choice) -> Void

    @State private var order: [Survey.Choice] = []
    @State private var handled = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog(survey.question, isPresented: $isPresented, titleVisibility: .visible) {
                ForEach(order) { choice in
                    Button(choice.title) {
                        handled = true
                        SurveyStore.shared.markHandled(survey.id)
                        onAnswer(choice)
                    }
                }
                Button(L10n.surveySkip) { handled = true }
            } message: {
                Text(L10n.surveyOnce)
            }
            .onChange(of: isPresented) { _, shown in
                if shown {
                    handled = false
                    order = survey.choices.shuffled() + survey.pinnedLast
                } else {
                    // Skip and outside-tap both land here; an answer already marked it.
                    SurveyStore.shared.markHandled(survey.id)
                }
            }
    }
}
