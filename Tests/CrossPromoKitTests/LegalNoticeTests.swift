@testable import CrossPromoKit
import Foundation
import Testing

@Suite("LegalNotice")
@MainActor
struct LegalNoticeTests {
    private let defaults = IsolatedDefaults()

    /// A fresh instance over the same storage, as on a new launch.
    private func notice() -> LegalNotice {
        LegalNotice(defaults: defaults.make())
    }

    /// An instance that already saw `2026-01-01` of both documents.
    private func seededNotice() -> LegalNotice {
        let notice = notice()
        notice.update(LegalVersions(terms: "2026-01-01", privacy: "2026-01-01"))
        return notice
    }

    @Test("The first versions seen are the baseline: nothing pending, nothing unread")
    func firstSightingIsSilent() {
        let notice = seededNotice()

        #expect(notice.pending.isEmpty)
        #expect(!notice.isUnread(.terms))
        #expect(!notice.isUnread(.privacy))
    }

    @Test("A newer version makes only that document pending and unread")
    func newerVersionIsAnnounced() {
        let notice = seededNotice()
        notice.update(LegalVersions(terms: "2026-03-01", privacy: "2026-01-01"))

        #expect(notice.pending == [.terms])
        #expect(notice.isUnread(.terms))
        #expect(!notice.isUnread(.privacy))
    }

    @Test("Acknowledging clears pending but leaves the document unread")
    func acknowledgeKeepsUnread() {
        let notice = seededNotice()
        notice.update(LegalVersions(terms: "2026-03-01", privacy: "2026-03-01"))
        notice.acknowledge()

        #expect(notice.pending.isEmpty)
        #expect(notice.isUnread(.terms))
        #expect(notice.isUnread(.privacy))
    }

    @Test("Opening a document clears it from pending and unread, and only it")
    func markReadClearsOneDocument() {
        let notice = seededNotice()
        notice.update(LegalVersions(terms: "2026-03-01", privacy: "2026-03-01"))
        notice.markRead(.terms)

        #expect(notice.pending == [.privacy])
        #expect(!notice.isUnread(.terms))
        #expect(notice.isUnread(.privacy))
    }

    @Test("Marks survive a relaunch")
    func marksPersist() {
        let first = seededNotice()
        first.update(LegalVersions(terms: "2026-03-01", privacy: "2026-01-01"))
        first.acknowledge()

        let relaunched = notice()
        relaunched.update(LegalVersions(terms: "2026-03-01", privacy: "2026-01-01"))

        #expect(relaunched.pending.isEmpty)
        #expect(relaunched.isUnread(.terms))
    }

    @Test("An unacknowledged change is still pending after a relaunch")
    func pendingSurvivesRelaunch() {
        seededNotice().update(LegalVersions(terms: "2026-03-01", privacy: "2026-01-01"))

        let relaunched = notice()
        relaunched.update(LegalVersions(terms: "2026-03-01", privacy: "2026-01-01"))

        #expect(relaunched.pending == [.terms])
    }

    @Test("An older version is not announced")
    func rollbackIsSilent() {
        let notice = seededNotice()
        notice.update(LegalVersions(terms: "2025-12-01", privacy: "2026-01-01"))

        #expect(notice.pending.isEmpty)
        #expect(!notice.isUnread(.terms))
    }

    @Test("A document that first appears later is a baseline too")
    func lateDocumentIsSilent() {
        let notice = notice()
        notice.update(LegalVersions(terms: "2026-01-01"))
        notice.update(LegalVersions(terms: "2026-01-01", privacy: "2026-02-01"))

        #expect(notice.pending.isEmpty)
        #expect(!notice.isUnread(.privacy))
    }

    @Test("A missing catalog entry keeps the previous state")
    func nilVersionsKeepState() {
        let notice = seededNotice()
        notice.update(LegalVersions(terms: "2026-03-01", privacy: "2026-01-01"))
        notice.update(nil)

        #expect(notice.pending == [.terms])
    }
}

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
