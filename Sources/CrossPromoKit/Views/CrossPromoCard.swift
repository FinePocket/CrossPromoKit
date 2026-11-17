import SwiftUI

/// A dismissible card that introduces one of your other apps inside a host
/// screen's content — for example between sections of a home list.
///
/// The card appears only when the catalog's ``CardRules`` allow it: after
/// enough launches or days, at most once per `intervalDays`, never for an app
/// the user closed within `dismissDays` or (with ``PromoApp/urlScheme``) one
/// that is already installed. One session keeps showing the same app.
///
/// Call ``recordLaunch(config:)`` once per app launch; it counts the launch and
/// prefetches the catalog. The card itself renders nothing until a card is due,
/// so it can sit in a `List` without leaving an empty row.
public struct CrossPromoCard: View {
    private let config: PromoConfig
    private let isHidden: Bool
    private let accent: Color
    private weak var eventDelegate: PromoEventDelegate?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var scheduler: CrossPromoCardScheduler { .shared }

    /// Creates the card.
    /// - Parameters:
    ///   - config: The same configuration passed to ``recordLaunch(config:)``.
    ///   - isHidden: Pass `true` for paying users: nothing is drawn and no
    ///     exposure is counted.
    ///   - accent: The host app's accent color, used for the Get button.
    ///   - eventDelegate: Receives `.impression` when the card first appears
    ///     and `.tap` when Get is tapped.
    public init(
        config: PromoConfig,
        isHidden: Bool,
        accent: Color,
        eventDelegate: PromoEventDelegate? = nil
    ) {
        self.config = config
        self.isHidden = isHidden
        self.accent = accent
        self.eventDelegate = eventDelegate
    }

    /// Counts one host-app launch and starts loading the catalog.
    ///
    /// Call it once per launch, for example from your `App` initializer.
    /// - Parameter config: Catalog URL and host app identifier.
    @MainActor
    public static func recordLaunch(config: PromoConfig) {
        let scheduler = CrossPromoCardScheduler.shared
        scheduler.recordLaunch()
        scheduler.load(config: config)
    }

    public var body: some View {
        if !isHidden, let service = scheduler.service, let app = scheduler.currentCard {
            card(app: app, service: service)
                .onAppear {
                    service.eventDelegate = eventDelegate
                    scheduler.markShown(app)
                    service.handleAppImpression(app)
                }
                .onDisappear {
                    // The overlay belongs to the window scene and would outlive the card.
                    service.dismissOverlay()
                }
        }
    }

    // MARK: - Subviews

    private func card(app: PromoApp, service: PromoService) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: WarmEmbraceTokens.spacingM))
            : AnyLayout(HStackLayout(spacing: WarmEmbraceTokens.spacingM))

        return ZStack(alignment: .topTrailing) {
            layout {
                info(app: app)
                getButton(app: app, service: service)
            }
            .padding(.vertical, WarmEmbraceTokens.spacingM)
            .padding(.leading, WarmEmbraceTokens.spacingM)
            .padding(.trailing, Self.closeTarget)
            .frame(maxWidth: .infinity, alignment: .leading)

            closeButton(app: app, service: service)
        }
        .background(
            RoundedRectangle(cornerRadius: WarmEmbraceTokens.cornerRadiusCard, style: .continuous)
                .fill(WarmEmbraceTokens.cardFill)
        )
        .accessibilityElement(children: .contain)
    }

    private func info(app: PromoApp) -> some View {
        HStack(spacing: WarmEmbraceTokens.spacingM) {
            AsyncAppIcon(url: app.iconURL, size: WarmEmbraceTokens.cardIconSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.cardEyebrow)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WarmEmbraceTokens.secondaryText)
                Text(app.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WarmEmbraceTokens.primaryText)
                Text(app.tagline.localized)
                    .font(.footnote)
                    .foregroundStyle(WarmEmbraceTokens.secondaryText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.cardLabel(name: app.name, tagline: app.tagline.localized))
    }

    private func getButton(app: PromoApp, service: PromoService) -> some View {
        Button {
            service.handleCardTap(app)
        } label: {
            Text(L10n.cardGet)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)
                .padding(.horizontal, WarmEmbraceTokens.spacingL)
                .padding(.vertical, 6)
                .background(Capsule().fill(accent.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func closeButton(app: PromoApp, service: PromoService) -> some View {
        Button {
            withAnimation(WarmEmbraceTokens.fadeAnimation) {
                scheduler.dismiss(app, rules: service.cardRules)
            }
        } label: {
            Image(systemName: "xmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(WarmEmbraceTokens.secondaryText)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color(.tertiarySystemFill)))
                .frame(width: Self.closeTarget, height: Self.closeTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.cardHide)
    }

    /// Hit target of the close button, also reserved on the card's trailing edge.
    private static let closeTarget: CGFloat = 44
}
