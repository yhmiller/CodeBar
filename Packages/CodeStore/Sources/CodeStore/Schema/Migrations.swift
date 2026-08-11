import CodeCore
import Foundation

/// Brings a database up to `Schema.version`.
enum Migrations {

    static func migrate(_ database: Database) throws {
        switch try resolveVersion(database) {
        case 0:
            try installFresh(database)
        case 1:
            try migrateV1ToV2(database)
        case Schema.version:
            return
        case let version:
            throw StoreError.unsupportedSchemaVersion(version)
        }
    }

    /// Distinguishes an empty file from one written by the pre-migration app.
    ///
    /// That build never set `user_version`, so its databases report 0 — the same
    /// value as a brand-new file. The bare `codes_fts` table without a companion
    /// `codes` table is what identifies the old shape.
    private static func resolveVersion(_ database: Database) throws -> Int32 {
        let stored = try database.userVersion()
        guard stored == 0 else { return stored }

        let hasLegacyTable = try database.tableExists("codes_fts")
        let hasCurrentTable = try database.tableExists("codes")
        return hasLegacyTable && !hasCurrentTable ? 1 : 0
    }

    private static func installFresh(_ database: Database) throws {
        try database.transaction {
            try database.execute(Schema.createV2)
        }
        try database.setUserVersion(Schema.version)
    }

    /// Rebuilds v1's single FTS5 table into the v2 schema.
    ///
    /// Rows are streamed through the normal upsert path rather than copied with
    /// `INSERT ... SELECT`, for two reasons: `code_norm` needs Swift-side
    /// normalization, and routing through the uniqueness constraint collapses
    /// any duplicates left behind by v1's non-idempotent import.
    private static func migrateV1ToV2(_ database: Database) throws {
        try database.transaction {
            try database.execute("ALTER TABLE codes_fts RENAME TO legacy_codes_fts;")
            try database.execute(Schema.createV2)
            try copyLegacyRows(database)
            try database.execute("DROP TABLE legacy_codes_fts;")
        }
        try database.setUserVersion(Schema.version)
    }

    private static func copyLegacyRows(_ database: Database) throws {
        let select = try database.prepare(
            "SELECT code, display, synonyms, system FROM legacy_codes_fts;"
        )
        let upsert = try database.prepare(Schema.upsertCode)

        while try select.step() {
            guard let code = select.string(at: 0),
                  let display = select.string(at: 1),
                  let systemRaw = select.string(at: 3),
                  let system = CodeSystem(rawValue: systemRaw)
            else { continue }

            // v1 stored synonyms space-joined, so multi-word synonyms were
            // already destroyed on the way in. Carry the tokens across rather
            // than inventing structure that was never there.
            let synonyms = (select.string(at: 2) ?? "")
                .split(separator: " ")
                .map(String.init)

            upsert.reset()
            try CodeBinder.bind(
                ClinicalCode(code: code, display: display, system: system, synonyms: synonyms),
                to: upsert
            )
            try upsert.step()
        }
    }
}
