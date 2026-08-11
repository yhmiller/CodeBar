import CodeCore
import Foundation
@testable import CodeStore

enum Fixtures {

    /// A handful of real ICD-10-CM and LOINC codes. Small enough to reason about,
    /// wide enough to cover both terminologies and multi-word synonyms.
    static let icd10: [ClinicalCode] = [
        ClinicalCode(
            code: "E11",
            display: "Type 2 diabetes mellitus",
            system: .icd10cm,
            synonyms: ["type 2 diabetes"]
        ),
        ClinicalCode(
            code: "E11.9",
            display: "Type 2 diabetes mellitus without complications",
            system: .icd10cm,
            synonyms: ["type 2 diabetes", "T2DM"]
        ),
        ClinicalCode(
            code: "E11.65",
            display: "Type 2 diabetes mellitus with hyperglycemia",
            system: .icd10cm,
            synonyms: ["hyperglycemia"]
        ),
        ClinicalCode(
            code: "E10.9",
            display: "Type 1 diabetes mellitus without complications",
            system: .icd10cm,
            synonyms: ["type 1 diabetes"]
        ),
        ClinicalCode(
            code: "I10",
            display: "Essential (primary) hypertension",
            system: .icd10cm,
            synonyms: ["high blood pressure"]
        )
    ]

    static let loinc: [ClinicalCode] = [
        ClinicalCode(
            code: "2160-0",
            display: "Creatinine [Mass/volume] in Serum or Plasma",
            system: .loinc,
            synonyms: ["serum creatinine"]
        ),
        ClinicalCode(
            code: "4548-4",
            display: "Hemoglobin A1c/Hemoglobin.total in Blood",
            system: .loinc,
            synonyms: ["hemoglobin a1c"]
        )
    ]

    static func store() throws -> SQLiteCodeStore {
        try SQLiteCodeStore(location: .inMemory)
    }

    static func seededStore() async throws -> SQLiteCodeStore {
        let store = try store()
        try await store.ingest(CodeSetImport(codes: icd10 + loinc))
        return store
    }
}

/// Builds a database in the pre-migration v1 shape: one bare FTS5 table, no
/// `user_version`, no uniqueness constraint.
struct LegacyDatabaseFixture {
    let directory: URL
    let url: URL

    init(rows: [ClinicalCode]) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codebar-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("codes.sqlite")

        let database = try Database(path: url.path)
        try database.execute("""
        CREATE VIRTUAL TABLE codes_fts USING fts5(
            code, display, synonyms, system UNINDEXED, tokenize='porter unicode61'
        );
        """)

        let insert = try database.prepare("""
        INSERT INTO codes_fts (code, display, synonyms, system)
        VALUES (:code, :display, :synonyms, :system);
        """)
        for row in rows {
            insert.reset()
            try insert.bind(row.code, to: ":code")
            try insert.bind(row.display, to: ":display")
            try insert.bind(row.synonyms.joined(separator: " "), to: ":synonyms")
            try insert.bind(row.system.rawValue, to: ":system")
            try insert.step()
        }
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }
}
