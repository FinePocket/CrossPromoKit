import SafariServices
import SwiftUI

public extension View {
    /// Announces a changed terms of use or privacy policy with a system alert.
    ///
    /// Attach it to the host's root screen. When the catalog's `legal` entry for
    /// `config.currentAppID` carries a newer version than the one last announced,
    /// an alert offers to open the changed document in an in-app Safari view.
    /// Each version is announced once; closing the alert leaves the document
    /// unread for ``LegalNotice/isUnread(_:)``. Nothing shows on a first launch,
    /// when offline with no cache, or when the catalog has no `legal` entry.
    /// - Parameters:
    ///   - config: The same configuration used for the promo UI.
    ///   - termsURL: Terms of use page. `nil` never announces terms changes.
    ///   - privacyURL: Privacy policy page. `nil` never announces privacy changes.
    ///   - isEnabled: Pass `false` to do nothing at all — for UI tests and
    ///     screenshot runs.
    func legalNotice(
        config: PromoConfig,
        termsURL: URL?,
        privacyURL: URL?,
        isEnabled: Bool = true
    ) -> some View {
        modifier(LegalNoticeModifier(
            config: config,
            urls: [.terms: termsURL, .privacy: privacyURL].compactMapValues { $0 },
            isEnabled: isEnabled
        ))
    }
}

struct LegalNoticeModifier: ViewModifier {
    let config: PromoConfig
    let urls: [LegalDocument: URL]
    let isEnabled: Bool

    @State private var page: LegalPage?
    @Environment(\.openURL) private var openURL

    private var notice: LegalNotice { .shared }

    /// Pending documents the host gave a page for.
    private var announced: [LegalDocument] {
        isEnabled ? notice.pending.filter { urls[$0] != nil } : []
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                if isEnabled { notice.start(config: config) }
            }
            .onChange(of: notice.service?.legalVersions, initial: true) { _, versions in
                if isEnabled { notice.update(versions) }
            }
            .alert(
                L10n.legalTitle(for: announced),
                isPresented: Binding(
                    get: { !announced.isEmpty },
                    set: { if !$0 { notice.acknowledge() } }
                )
            ) {
                ForEach(announced, id: \.self) { document in
                    Button(L10n.legalView(document)) { open(document) }
                }
                Button(L10n.legalClose, role: .cancel) {}
            } message: {
                Text(L10n.legalMessage)
            }
            .sheet(item: $page) { page in
                SafariView(url: page.url).ignoresSafeArea()
            }
    }

    private func open(_ document: LegalDocument) {
        guard let url = urls[document] else { return }
        notice.markRead(document)
        // SFSafariViewController raises on anything but http(s).
        if ["http", "https"].contains(url.scheme?.lowercased()) {
            page = LegalPage(url: url)
        } else {
            openURL(url)
        }
    }
}

private struct LegalPage: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
