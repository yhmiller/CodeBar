import CodeCore
import SQLiteKit
import Foundation

enum Migrations {

    static func migrate(_ database: Database) throws {
        var version = try resolveVersion(database)

        while version < Schema.version {
            switch version {
            case 0:
                try installFresh(database)
            case 1:
                try migrateLegacyToCurrent(database)
            case 2:
                try migrateV2ToV3(database)
            case 3:
                try migrateV3ToV4(database)
            case 4:
                try migrateV4ToV5(database)
            default:
                throw StoreError.unsupportedSchemaVersion(version)
            }
            version = try database.userVersion()
        }

        guard version == Schema.version else {
            throw StoreError.unsupportedSchemaVersion(version)
        }
    }

    private static func resolveVersion(_ database: Database) throws -> Int32 {
        let stored = try database.userVersion()
        guard stored == 0 else { return stored }

        let hasLegacyTable = try database.tableExists("codes_fts")
        let hasCurrentTable = try database.tableExists("codes")
        return hasLegacyTable && !hasCurrentTable ? 1 : 0
    }

    private static func installFresh(_ database: Database) throws {
        try database.transaction {
            try database.execute(Schema.createSchema)
        }
        try database.setUserVersion(Schema.version)
    }

    private static func migrateLegacyToCurrent(_ database: Database) throws {
        try database.transaction {
            try database.execute("ALTER TABLE codes_fts RENAME TO legacy_codes_fts;")
            try database.execute(Schema.createSchema)
            try copyLegacyRows(database)
            try database.execute("DROP TABLE legacy_codes_fts;")
        }
        try database.setUserVersion(Schema.version)
    }

    private static func migrateV2ToV3(_ database: Database) throws {
        try database.transaction {
            try database.execute(Schema.migrateV2ToV3)
        }
        try database.setUserVersion(3)
    }

    private static func migrateV3ToV4(_ database: Database) throws {
        try database.transaction {
            try database.execute(Schema.migrateV3ToV4)
        }
        try database.setUserVersion(4)
    }

    private static func migrateV4ToV5(_ database: Database) throws {
        try database.transaction {
            try database.execute(Schema.migrateV4ToV5)
        }
        try database.setUserVersion(5)
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
