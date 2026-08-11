import CodeCore
import Foundation
@testable import CodeStore

enum Fixtures {

    /// A handful of real ICD-10-CM and LOINC codes. Small enough to reason about,
    /// wide enough to cover both terminologies and multi-word synonyms.
    static let icd10: [ClinicalCode] = [
        // A real ICD-10-CM category header: not valid for submission on its own.
        ClinicalCode(
            code: "E11",
            display: "Type 2 diabetes mellitus",
            system: .icd10cm,
            synonyms: ["type 2 diabetes"],
            isBillable: false
        ),
        ClinicalCode(
            code: "E11.9",
            display: "Type 2 diabetes mellitus without complications",
            system: .icd10cm,
            synonyms: ["type 2 diabetes", "T2DM"],
            isBillable: true
        ),
        ClinicalCode(
            code: "E11.65",
            display: "Type 2 diabetes mellitus with hyperglycemia",
            system: .icd10cm,
            synonyms: ["hyperglycemia"],
            isBillable: true
        ),
        ClinicalCode(
            code: "E10.9",
            display: "Type 1 diabetes mellitus without complications",
            system: .icd10cm,
            synonyms: ["type 1 diabetes"],
            isBillable: true
        ),
        ClinicalCode(
            code: "I10",
            display: "Essential (primary) hypertension",
            system: .icd10cm,
            synonyms: ["high blood pressure"],
            isBillable: true
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

/// Builds a database in the v2 shape: the current tables, but without the
/// `is_billable` column added in v3.
///
/// The DDL is deliberately a frozen copy rather than a reference to `Schema` —
/// a migration test that follows the current schema forward tests nothing.
struct V2DatabaseFixture {
    let directory: URL
    let url: URL

    static let ddl = """
    CREATE TABLE code_sets (
        system      TEXT PRIMARY KEY,
        release     TEXT,
        imported_at INTEGER NOT NULL
    );

    CREATE TABLE codes (
        id            INTEGER PRIMARY KEY,
        system        TEXT NOT NULL,
        code          TEXT NOT NULL,
        code_norm     TEXT NOT NULL,
        display       TEXT NOT NULL,
        synonyms_json TEXT NOT NULL DEFAULT '[]',
        synonyms_text TEXT NOT NULL DEFAULT '',
        UNIQUE(system, code)
    );

    CREATE INDEX idx_codes_code_norm ON codes(code_norm);
    CREATE INDEX idx_codes_system    ON codes(system);

    CREATE VIRTUAL TABLE codes_fts USING fts5(
        display, synonyms_text,
        content = 'codes', content_rowid = 'id', tokenize = 'porter unicode61'
    );

    CREATE TRIGGER codes_ai AFTER INSERT ON codes BEGIN
        INSERT INTO codes_fts(rowid, display, synonyms_text)
        VALUES (new.id, new.display, new.synonyms_text);
    END;
    """

    init(rows: [ClinicalCode]) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codebar-v2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("codes.sqlite")

        let database = try Database(path: url.path)
        try database.execute(Self.ddl)

        let insert = try database.prepare("""
        INSERT INTO codes (system, code, code_norm, display, synonyms_json, synonyms_text)
        VALUES (:system, :code, :code_norm, :display, :synonyms_json, :synonyms_text);
        """)
        for row in rows {
            insert.reset()
            try insert.bind(row.system.rawValue, to: ":system")
            try insert.bind(row.code, to: ":code")
            try insert.bind(row.normalizedCode, to: ":code_norm")
            try insert.bind(row.display, to: ":display")
            try insert.bind("[]", to: ":synonyms_json")
            try insert.bind(row.synonyms.joined(separator: " "), to: ":synonyms_text")
            try insert.step()
        }
        try database.setUserVersion(2)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }
}
