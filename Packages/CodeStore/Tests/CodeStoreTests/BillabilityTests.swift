import CodeCore
import Foundation
import Testing
@testable import CodeStore

@Suite("Billability")
struct BillabilityTests {

    @Test("should round-trip a billable code's flag")
    func roundTripsBillableFlag() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "E11.9"))

        #expect(results.first?.code.isBillable == true)
    }

    @Test("should round-trip a category header's flag")
    func roundTripsHeaderFlag() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "E11"))

        #expect(results.first(where: { $0.code.code == "E11" })?.code.isBillable == false)
    }

    @Test("should report unknown billability when the source does not say")
    func unknownWhenSourceIsSilent() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "creatinine"))

        #expect(results.first?.code.isBillable == nil)
    }

    @Test("should rank a billable code above a category header within a tier")
    func billableOutranksHeader() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: [
            ClinicalCode(code: "J45", display: "Asthma", system: .icd10cm, isBillable: false),
            ClinicalCode(code: "J45.909", display: "Asthma unspecified", system: .icd10cm, isBillable: true)
        ]))

        let results = try await store.search(SearchQuery(raw: "asthma"))

        #expect(results.first?.code.code == "J45.909")
    }

    @Test("should still return category headers rather than hiding them")
    func headersRemainFindable() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "E11"))

        #expect(results.contains { $0.code.code == "E11" })
    }

    @Test("should not penalise a code whose billability is unknown")
    func unknownBillabilityIsNotPenalised() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: [
            ClinicalCode(code: "J45", display: "Asthma", system: .icd10cm, isBillable: false),
            ClinicalCode(code: "J46", display: "Asthma variant", system: .icd10cm)
        ]))

        let results = try await store.search(SearchQuery(raw: "asthma"))

        #expect(results.first?.code.code == "J46")
    }

    @Test("should decode the billable flag from the import format")
    func decodesBillableFlag() throws {
        let json = """
        [{"code":"E11","display":"Type 2 diabetes mellitus","system":"ICD-10-CM","billable":false}]
        """
        let codeSet = try CodeSetDecoder.decode(Data(json.utf8))

        #expect(codeSet.codes.first?.isBillable == false)
    }

    @Test("should treat a missing billable key as unknown")
    func missingBillableKeyIsUnknown() throws {
        let json = """
        [{"code":"I10","display":"Essential (primary) hypertension","system":"ICD-10-CM"}]
        """
        let codeSet = try CodeSetDecoder.decode(Data(json.utf8))

        #expect(codeSet.codes.first?.isBillable == nil)
    }

    @Test("should keep a known flag when a later import omits it")
    func laterImportDoesNotEraseKnownFlag() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: [
            ClinicalCode(code: "E11", display: "Type 2 diabetes mellitus", system: .icd10cm, isBillable: false)
        ]))

        try await store.ingest(CodeSetImport(codes: [
            ClinicalCode(code: "E11", display: "Type 2 diabetes mellitus", system: .icd10cm)
        ]))

        let results = try await store.search(SearchQuery(raw: "E11"))
        #expect(results.first?.code.isBillable == false)
    }
}
