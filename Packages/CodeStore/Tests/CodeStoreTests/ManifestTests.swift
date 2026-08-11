import CodeCore
import Testing
@testable import CodeStore

@Suite("Manifests")
struct ManifestTests {

    @Test("should record one manifest per imported system")
    func recordsOneManifestPerSystem() async throws {
        let store = try await Fixtures.seededStore()

        #expect(try await store.manifests().count == 2)
    }

    @Test("should report the release stamp supplied at import")
    func reportsRelease() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10, release: "2026"))

        #expect(try await store.manifests().first?.release == "2026")
    }

    @Test("should report the live row count for a system")
    func reportsRowCount() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10, release: "2026"))

        #expect(try await store.manifests().first?.rowCount == Fixtures.icd10.count)
    }

    @Test("should keep an earlier release stamp when a later merge carries none")
    func keepsEarlierReleaseOnUnstampedMerge() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10, release: "2026"))

        try await store.ingest(CodeSetImport(codes: Array(Fixtures.icd10.prefix(1))))

        #expect(try await store.manifests().first?.release == "2026")
    }

    @Test("should delete only the named system's codes when removing a code set")
    func removeDeletesOnlyThatSystem() async throws {
        let store = try await Fixtures.seededStore()

        try await store.removeCodeSet(.icd10cm)

        #expect(try await store.codeCount() == Fixtures.loinc.count)
    }

    @Test("should report the number of rows deleted when removing a code set")
    func removeReportsDeletedCount() async throws {
        let store = try await Fixtures.seededStore()

        let deleted = try await store.removeCodeSet(.icd10cm)

        #expect(deleted == Fixtures.icd10.count)
    }

    @Test("should drop the manifest when its code set is removed")
    func removeDropsManifest() async throws {
        let store = try await Fixtures.seededStore()

        try await store.removeCodeSet(.icd10cm)

        #expect(try await store.manifests().map(\.system) == [.loinc])
    }

    @Test("should stop returning removed codes from search")
    func removedCodesAreNotSearchable() async throws {
        let store = try await Fixtures.seededStore()

        try await store.removeCodeSet(.icd10cm)

        #expect(try await store.search(SearchQuery(raw: "hypertension")).isEmpty)
    }
}
