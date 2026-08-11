import CodeCore
import Foundation
import Testing
@testable import CodeStore

@Suite("Ingest")
struct IngestTests {

    @Test("should leave the row count unchanged when the same set is imported twice")
    func reimportIsIdempotent() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10))
        let afterFirst = try await store.codeCount()

        try await store.ingest(CodeSetImport(codes: Fixtures.icd10))

        #expect(try await store.codeCount() == afterFirst)
    }

    @Test("should report no net additions when the same set is imported twice")
    func reimportReportsNoNetAdditions() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10))

        let summary = try await store.ingest(CodeSetImport(codes: Fixtures.icd10))

        #expect(summary.isUnchanged)
    }

    @Test("should update the display text when a code is re-imported with a new description")
    func reimportUpdatesDisplay() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10))

        let revised = ClinicalCode(
            code: "E11.9",
            display: "Type 2 diabetes mellitus without complications, revised",
            system: .icd10cm
        )
        try await store.ingest(CodeSetImport(codes: [revised]))

        let results = try await store.search(SearchQuery(raw: "E11.9"))
        #expect(results.first?.code.display == revised.display)
    }

    @Test("should delete codes absent from the batch when importing in replace mode")
    func replaceModeRemovesRetiredCodes() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10))

        let currentRelease = Array(Fixtures.icd10.prefix(2))
        try await store.ingest(CodeSetImport(codes: currentRelease, release: "2026", mode: .replace))

        #expect(try await store.codeCount() == currentRelease.count)
    }

    @Test("should keep codes from other systems when replacing one system")
    func replaceModeIsScopedToItsOwnSystems() async throws {
        let store = try await Fixtures.seededStore()

        try await store.ingest(
            CodeSetImport(codes: Array(Fixtures.icd10.prefix(1)), mode: .replace)
        )

        let remaining = try await store.search(SearchQuery(raw: "creatinine"))
        #expect(remaining.count == 1)
    }

    @Test("should keep codes absent from the batch when importing in merge mode")
    func mergeModeKeepsExistingCodes() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10))

        try await store.ingest(CodeSetImport(codes: Array(Fixtures.icd10.prefix(1)), mode: .merge))

        #expect(try await store.codeCount() == Fixtures.icd10.count)
    }

    @Test("should report the net number of codes retired by a replace import")
    func replaceModeReportsNetRetired() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10))

        let summary = try await store.ingest(
            CodeSetImport(codes: Array(Fixtures.icd10.prefix(2)), mode: .replace)
        )

        #expect(summary.retired == Fixtures.icd10.count - 2)
    }

    @Test("should never report a negative number of additions")
    func neverReportsNegativeAdditions() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10))

        let summary = try await store.ingest(
            CodeSetImport(codes: Array(Fixtures.icd10.prefix(2)), mode: .replace)
        )

        #expect(summary.added == 0)
    }

    @Test("should report how many codes are installed after a replace import")
    func reportsInstalledCountAfterReplace() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10))

        let summary = try await store.ingest(
            CodeSetImport(codes: Array(Fixtures.icd10.prefix(2)), mode: .replace)
        )

        #expect(summary.installed == 2)
    }

    @Test("should scope its counts to the systems the file touches")
    func scopesCountsToAffectedSystems() async throws {
        let store = try await Fixtures.seededStore()

        let summary = try await store.ingest(
            CodeSetImport(codes: Array(Fixtures.icd10.prefix(1)), mode: .replace)
        )

        #expect(summary.installed == 1)
    }

    @Test("should decode the bare-array JSON format emitted by the import scripts")
    func decodesBareArrayFormat() throws {
        let json = """
        [{"code":"E11.9","display":"Type 2 diabetes mellitus without complications",
          "system":"ICD-10-CM","synonyms":["type 2 diabetes"]}]
        """
        let codeSet = try CodeSetDecoder.decode(Data(json.utf8))

        #expect(codeSet.codes.first?.code == "E11.9")
    }

    @Test("should default synonyms to empty when the JSON omits them")
    func decodesMissingSynonyms() throws {
        let json = """
        [{"code":"I10","display":"Essential (primary) hypertension","system":"ICD-10-CM"}]
        """
        let codeSet = try CodeSetDecoder.decode(Data(json.utf8))

        #expect(codeSet.codes.first?.synonyms == [])
    }
}
