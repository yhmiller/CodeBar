import CodeCore
import SQLiteKit
import Foundation
import Testing
@testable import CodeStore

/// Tests that the `isUnspecified` field set by TypeSafe Noul enrichment
/// round-trips correctly through the import pipeline, SQLite schema, and search.
struct UnspecifiedBadgeTests {

    // MARK: - Persistence

    @Test("isUnspecified: true is persisted and read back via detail()")
    func unspecifiedFlagRoundTripsViaDetail() async throws {
        let store = try await Fixtures.seededStore()

        let code = Fixtures.icd10.first { $0.code == "E11.9" }!
        let detail = try await store.detail(for: code)

        #expect(detail != nil)
        #expect(detail?.code.isUnspecified == true)
    }

    @Test("isUnspecified: nil for codes that were not enriched")
    func unannotatedCodeHasNilIsUnspecified() async throws {
        let store = try await Fixtures.seededStore()

        let code = Fixtures.icd10.first { $0.code == "E11.65" }!
        let detail = try await store.detail(for: code)

        #expect(detail != nil)
        #expect(detail?.code.isUnspecified == nil)
    }

    @Test("isUnspecified: false is persisted and read back")
    func specificFlagRoundTrips() async throws {
        let store = try store()
        let specificCode = ClinicalCode(
            code: "N18.5",
            display: "Chronic kidney disease, stage 5",
            system: .icd10cm,
            isBillable: true,
            isUnspecified: false
        )
        try await store.ingest(CodeSetImport(codes: [specificCode]))

        let detail = try await store.detail(for: specificCode)
        #expect(detail?.code.isUnspecified == false)
    }

    // MARK: - Search results

    @Test("Search results carry isUnspecified from the codes table")
    func searchResultsCarryIsUnspecified() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(
            SearchQuery(raw: "diabetes", systems: [.icd10cm])
        )

        let e119 = results.first { $0.code.code == "E11.9" }
        let e1165 = results.first { $0.code.code == "E11.65" }

        #expect(e119 != nil)
        #expect(e119?.code.isUnspecified == true)

        #expect(e1165 != nil)
        #expect(e1165?.code.isUnspecified == nil)
    }

    // MARK: - Migration

    @Test("v4→v5 migration adds is_unspecified column as NULL for existing rows")
    func migrationV4ToV5SetsExistingRowsToNull() throws {
        // Build a v4-schema database, insert a code without is_unspecified,
        // then let migrations run and confirm the column exists with NULL.
        let fixture = try V2DatabaseFixture(rows: [
            ClinicalCode(code: "I10", display: "Essential hypertension",
                         system: .icd10cm, isBillable: true)
        ])
        defer { fixture.cleanUp() }

        // Manually set user_version to 4 to test only the v4→v5 step
        let db = try Database(path: fixture.url.path)
        // Add columns that v3→v4 would have added (fixture is v2 shape)
        try? db.execute("ALTER TABLE codes ADD COLUMN parent_code TEXT;")
        try? db.execute("ALTER TABLE codes ADD COLUMN chapter TEXT;")
        try? db.execute("ALTER TABLE codes ADD COLUMN is_billable INTEGER;")
        try? db.execute("""
            CREATE TABLE IF NOT EXISTS code_notes (
                id INTEGER PRIMARY KEY,
                system TEXT NOT NULL, code TEXT NOT NULL,
                kind TEXT NOT NULL, text TEXT NOT NULL,
                sort_order INTEGER NOT NULL
            );
        """)
        try db.setUserVersion(4)

        // Opening the store should run migrations automatically
        let store = try SQLiteCodeStore(location: .file(fixture.url))
        _ = store   // force init

        // Verify the column exists and existing rows have NULL
        let db2 = try Database(path: fixture.url.path)
        let stmt = try db2.prepare(
            "SELECT is_unspecified FROM codes WHERE code = 'I10';"
        )
        let stepped = try stmt.step()
        #expect(stepped)
        #expect(stmt.string(at: 0) == nil, "Existing rows should have NULL is_unspecified")
    }

    // MARK: - JSON codec

    @Test("ClinicalCode decodes 'unspecified' JSON key into isUnspecified")
    func jsonDecodesUnspecifiedField() throws {
        let json = """
        {
          "code": "E11.9",
          "display": "Type 2 diabetes mellitus without complications",
          "system": "ICD-10-CM",
          "synonyms": [],
          "unspecified": true
        }
        """.data(using: .utf8)!

        let code = try JSONDecoder().decode(ClinicalCode.self, from: json)
        #expect(code.isUnspecified == true)
    }

    @Test("ClinicalCode encodes isUnspecified as 'unspecified' JSON key")
    func jsonEncodesIsUnspecifiedField() throws {
        let code = ClinicalCode(
            code: "E11.9",
            display: "Type 2 diabetes mellitus without complications",
            system: .icd10cm,
            isUnspecified: true
        )

        let data = try JSONEncoder().encode(code)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["unspecified"] as? Bool == true)
    }

    @Test("ClinicalCode omits 'unspecified' key when isUnspecified is nil")
    func jsonOmitsUnspecifiedWhenNil() throws {
        let code = ClinicalCode(
            code: "E11.65",
            display: "Type 2 diabetes mellitus with hyperglycemia",
            system: .icd10cm
        )

        let data = try JSONEncoder().encode(code)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["unspecified"] == nil)
    }

    // MARK: - Helpers

    private func store() throws -> SQLiteCodeStore {
        try SQLiteCodeStore(location: .inMemory)
    }
}
