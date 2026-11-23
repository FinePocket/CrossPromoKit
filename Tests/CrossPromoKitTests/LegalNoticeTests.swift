@testable import CrossPromoKit
import Foundation
import Testing

@Suite("Legal catalog decoding")
struct LegalCatalogDecodingTests {
    @Test("Legal versions decode per app ID; a missing document is nil")
    func decodesLegal() throws {
        let json = Data(#"""
        {"apps":[],"legal":{"app.a":{"terms":"2026-11-18","privacy":"2026-11-01"},"app.b":{"privacy":"2026-10-17"}}}
        """#.utf8)
        let catalog = try JSONDecoder().decode(AppCatalog.self, from: json)

        #expect(catalog.legal?["app.a"] == LegalVersions(terms: "2026-11-18", privacy: "2026-11-01"))
        #expect(catalog.legal?["app.b"] == LegalVersions(privacy: "2026-10-17"))
    }

    @Test("A catalog without legal, or with a malformed one, still decodes")
    func toleratesMissingOrMalformedLegal() throws {
        let legacy = try JSONDecoder().decode(AppCatalog.self, from: Data(#"{"apps":[]}"#.utf8))
        let malformed = try JSONDecoder().decode(AppCatalog.self, from: Data(#"{"apps":[],"legal":"yes"}"#.utf8))

        #expect(legacy.legal == nil)
        #expect(malformed.legal == nil)
    }
}

@Suite("PromoService legal versions")
@MainActor
struct PromoServiceLegalTests {
    @Test("A load publishes the host app's entry, not another app's")
    func publishesHostEntry() async throws {
        let catalog = AppCatalog(
            apps: [Fixture.app(id: "other")],
            legal: ["host": LegalVersions(terms: "2026-11-18"), "other": LegalVersions(terms: "2020-01-01")]
        )
        let url = try makeTemporaryFile(contents: Fixture.json(for: catalog))
        defer { removeTemporaryFile(at: url) }
        let defaults = IsolatedDefaults()
        defer { defaults.remove() }

        let service = PromoService(
            config: PromoConfig(jsonURL: url, currentAppID: "host"),
            cacheManager: CacheManager(scope: url, userDefaults: defaults.make())
        )
        await service.loadApps()

        #expect(service.legalVersions == LegalVersions(terms: "2026-11-18"))
    }
}
