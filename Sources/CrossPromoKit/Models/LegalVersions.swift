import Foundation

/// A legal document whose changes ``LegalNotice`` announces.
public enum LegalDocument: String, Sendable, CaseIterable {
    /// Terms of use / terms of service.
    case terms
    /// Privacy policy.
    case privacy
}

/// Current versions of one app's legal documents, from the catalog's `legal` object.
///
/// A version is an opaque string that must sort ascending as the document is
/// revised — an ISO date such as `"2026-11-18"` is the intended form. A
/// document without a version is never announced.
public struct LegalVersions: Codable, Sendable, Equatable {
    /// Version of the terms of use, if published.
    public let terms: String?
    /// Version of the privacy policy, if published.
    public let privacy: String?

    public init(terms: String? = nil, privacy: String? = nil) {
        self.terms = terms
        self.privacy = privacy
    }

    /// The version of `document`, or `nil` when the catalog does not carry one.
    public func version(of document: LegalDocument) -> String? {
        switch document {
        case .terms: terms
        case .privacy: privacy
        }
    }
}
