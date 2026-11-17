import Foundation

/// Localized text container with English as required fallback.
/// Supports English (en), Korean (ko), Japanese (ja), Arabic (ar), German (de),
/// Spanish (es), and Thai (th).
public struct LocalizedText: Codable, Sendable, Equatable {
    /// English text (required fallback)
    public let en: String
    /// Korean text (optional)
    public let ko: String?
    /// Japanese text (optional)
    public let ja: String?
    /// Arabic text (optional)
    public let ar: String?
    /// German text (optional)
    public let de: String?
    /// Spanish text (optional)
    public let es: String?
    /// Thai text (optional)
    public let th: String?

    public init(
        en: String,
        ko: String? = nil,
        ja: String? = nil,
        ar: String? = nil,
        de: String? = nil,
        es: String? = nil,
        th: String? = nil
    ) {
        self.en = en
        self.ko = ko
        self.ja = ja
        self.ar = ar
        self.de = de
        self.es = es
        self.th = th
    }

    /// Returns the appropriate text based on device locale, falling back to English.
    public var localized: String {
        localized(for: Locale.current.supportedLanguage)
    }

    /// Returns the text for a specific language, falling back to English when missing.
    /// - Parameter language: The language to resolve
    /// - Returns: The localized text, or the English text if unavailable
    public func localized(for language: Locale.SupportedLanguage) -> String {
        switch language {
        case .korean:
            return ko ?? en
        case .japanese:
            return ja ?? en
        case .arabic:
            return ar ?? en
        case .german:
            return de ?? en
        case .spanish:
            return es ?? en
        case .thai:
            return th ?? en
        case .english:
            return en
        }
    }
}
