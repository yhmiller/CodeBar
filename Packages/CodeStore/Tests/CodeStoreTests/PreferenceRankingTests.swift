import CodeCore
import Foundation
import Testing
@testable import CodeStore

@Suite("Preference ranking")
struct PreferenceRankingTests {

    private let codes: [ClinicalCode] = [
        ClinicalCode(code: "E11", display: "Type 2 diabetes mellitus",
                     system: .icd10cm, isBillable: false),
        ClinicalCode(code: "E11.9", display: "Type 2 diabetes mellitus without complications",
                     system: .icd10cm, isBillable: true),
        ClinicalCode(code: "E13.41", display: "Other specified diabetes mellitus with diabetic mononeuropathy",
                     system: .icd10cm, isBillable: true),
        ClinicalCode(code: "E10.21", display: "Type 1 diabetes mellitus with diabetic nephropathy",
                     system: .icd10cm, isBillable: true)
    ]

    private func seeded() async throws -> SQLiteCodeStore {
        let store = try SQLiteCodeStore(location: .inMemory)
        try await store.ingest(CodeSetImport(codes: codes))
        return store
    }

    @Test("should rank a preferred code first among text matches")
    func preferredCodeRanksFirst() async throws {
        let results = try await seeded().search(
            SearchQuery(raw: "diabetes", preferredCodes: ["ICD-10-CM-E11.9"])
        )
        #expect(results.first?.code.code == "E11.9")
    }

    @Test("should leave ranking alone when nothing is preferred")
    func noPreferenceLeavesOrderAlone() async throws {
        let store = try await seeded()
        let plain = try await store.search(SearchQuery(raw: "diabetes")).map(\.code.code)
        let empty = try await store.search(
            SearchQuery(raw: "diabetes", preferredCodes: [])
        ).map(\.code.code)

        #expect(plain == empty)
    }

    @Test("should not let preference override an exact code match")
    func exactCodeStillWins() async throws {
        // Someone typing E11 means E11, however often they have used E11.9.
        let results = try await seeded().search(
            SearchQuery(raw: "E11", preferredCodes: ["ICD-10-CM-E11.9"])
        )
        #expect(results.first?.code.code == "E11")
    }

    @Test("should admit a preferred code that relevance alone would exclude")
    func preferredCodeEntersResultSet() async throws {
        let results = try await seeded().search(
            SearchQuery(raw: "diabetes", limit: 1, preferredCodes: ["ICD-10-CM-E10.21"])
        )
        #expect(results.map(\.code.code) == ["E10.21"])
    }

    @Test("should not admit a preferred code that does not match the query")
    func preferenceDoesNotBypassMatching() async throws {
        let results = try await seeded().search(
            SearchQuery(raw: "nephropathy", preferredCodes: ["ICD-10-CM-E11.9"])
        )
        #expect(results.contains { $0.code.code == "E11.9" } == false)
    }

    @Test("should keep preferring a code the user pinned but never used")
    func preferenceWorksFromASingleSignal() async throws {
        let results = try await seeded().search(
            SearchQuery(raw: "diabetes", preferredCodes: ["ICD-10-CM-E10.21"])
        )
        #expect(results.first?.code.code == "E10.21")
    }

    @Test("should still rank a billable code above a header among preferred codes")
    func billabilityStillApplies() async throws {
        let results = try await seeded().search(
            SearchQuery(raw: "diabetes",
                        preferredCodes: ["ICD-10-CM-E11", "ICD-10-CM-E11.9"])
        )
        #expect(results.first?.code.code == "E11.9")
    }
}
