import CodeCore
import SQLiteKit
import Testing
@testable import CodeStore

@Suite("Migration from v1")
struct MigrationTests {

    @Test("should carry every legacy code across to the new schema")
    func preservesLegacyCodes() async throws {
        let fixture = try LegacyDatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        let store = try SQLiteCodeStore(location: .file(fixture.url))

        #expect(try await store.codeCount() == Fixtures.icd10.count)
    }

    @Test("should collapse duplicate rows left behind by v1's non-idempotent import")
    func collapsesLegacyDuplicates() async throws {
        let fixture = try LegacyDatabaseFixture(rows: Fixtures.icd10 + Fixtures.icd10)
        defer { fixture.cleanUp() }

        let store = try SQLiteCodeStore(location: .file(fixture.url))

        #expect(try await store.codeCount() == Fixtures.icd10.count)
    }

    @Test("should leave migrated codes searchable by description")
    func migratedCodesAreSearchable() async throws {
        let fixture = try LegacyDatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        let store = try SQLiteCodeStore(location: .file(fixture.url))
        let results = try await store.search(SearchQuery(raw: "hypertension"))

        #expect(results.first?.code.code == "I10")
    }

    @Test("should backfill normalized codes so migrated codes match an undotted query")
    func migratedCodesMatchUndottedQuery() async throws {
        let fixture = try LegacyDatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        let store = try SQLiteCodeStore(location: .file(fixture.url))
        let results = try await store.search(SearchQuery(raw: "E119"))

        #expect(results.contains { $0.code.code == "E11.9" })
    }

    @Test("should be a no-op when reopening an already migrated database")
    func reopeningIsIdempotent() async throws {
        let fixture = try LegacyDatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        _ = try SQLiteCodeStore(location: .file(fixture.url))
        let reopened = try SQLiteCodeStore(location: .file(fixture.url))

        #expect(try await reopened.codeCount() == Fixtures.icd10.count)
    }

    @Test("should drop the legacy table once migration completes")
    func removesLegacyTable() async throws {
        let fixture = try LegacyDatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        _ = try SQLiteCodeStore(location: .file(fixture.url))

        let database = try Database(path: fixture.url.path)
        #expect(try database.tableExists("legacy_codes_fts") == false)
    }

    @Test("should record the current schema version after migrating")
    func stampsSchemaVersion() async throws {
        let fixture = try LegacyDatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        _ = try SQLiteCodeStore(location: .file(fixture.url))

        let database = try Database(path: fixture.url.path)
        #expect(try database.userVersion() == Schema.version)
    }

    @Test("should migrate a v2 database to the current schema")
    func migratesV2ToCurrent() async throws {
        let fixture = try V2DatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        _ = try SQLiteCodeStore(location: .file(fixture.url))

        let database = try Database(path: fixture.url.path)
        #expect(try database.userVersion() == Schema.version)
    }

    @Test("should keep every v2 row when adding the billability column")
    func v2MigrationPreservesRows() async throws {
        let fixture = try V2DatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        let store = try SQLiteCodeStore(location: .file(fixture.url))

        #expect(try await store.codeCount() == Fixtures.icd10.count)
    }

    @Test("should report unknown billability for rows that predate the column")
    func v2RowsReportUnknownBillability() async throws {
        let fixture = try V2DatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        let store = try SQLiteCodeStore(location: .file(fixture.url))
        let results = try await store.search(SearchQuery(raw: "E11.9"))

        #expect(results.first?.code.isBillable == nil)
    }

    @Test("should leave migrated v2 rows searchable")
    func v2MigratedRowsAreSearchable() async throws {
        let fixture = try V2DatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        let store = try SQLiteCodeStore(location: .file(fixture.url))

        #expect(try await store.search(SearchQuery(raw: "hypertension")).first?.code.code == "I10")
    }

    @Test("should add hierarchy columns when migrating a v3 database")
    func migratesV3ToV4() async throws {
        let fixture = try V2DatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        _ = try SQLiteCodeStore(location: .file(fixture.url))

        let database = try Database(path: fixture.url.path)
        #expect(try database.tableExists("code_notes"))
    }

    @Test("should report no parent for rows that predate the hierarchy columns")
    func preV4RowsHaveNoParent() async throws {
        let fixture = try V2DatabaseFixture(rows: Fixtures.icd10)
        defer { fixture.cleanUp() }

        let store = try SQLiteCodeStore(location: .file(fixture.url))
        let roots = try await store.children(of: nil, in: .icd10cm)

        #expect(roots.count == Fixtures.icd10.count)
    }

    @Test("should refuse to open a database written by a newer schema")
    func rejectsNewerSchema() async throws {
        let fixture = try LegacyDatabaseFixture(rows: [])
        defer { fixture.cleanUp() }

        let database = try Database(path: fixture.url.path)
        try database.setUserVersion(Schema.version + 1)

        #expect(throws: StoreError.unsupportedSchemaVersion(Schema.version + 1)) {
            _ = try SQLiteCodeStore(location: .file(fixture.url))
        }
    }
}
