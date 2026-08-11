import CodeCore
import Foundation
import SQLiteKit

/// SQLite implementation of the user's library.
public actor SQLiteCodeLibrary: CodeLibraryStoring {

    public enum Location: Sendable {
        case inMemory
        /// `~/Library/…/CodeBar/library.sqlite`, alongside but separate from the
        /// code index. Separate files because their lifecycles are opposite: the
        /// index is replaced by a yearly release, this must survive every one.
        case applicationSupport
        case file(URL)
    }

    private let database: Database

    public init(location: Location = .applicationSupport) throws {
        database = try Database(path: try location.path())
        try database.configure()
        try Self.migrate(database)
    }

    /// Static so it can run from `init`, which cannot call isolated members.
    private static func migrate(_ database: Database) throws {
        let version = try database.userVersion()
        guard version != LibrarySchema.version else { return }

        // Steps forward one version at a time, so a library from any earlier
        // build arrives intact rather than only the immediately previous one.
        var current = version
        while current < LibrarySchema.version {
            switch current {
            case 0:
                try database.transaction { try database.execute(LibrarySchema.create) }
                try database.setUserVersion(LibrarySchema.version)
            case 1:
                try database.transaction { try database.execute(LibrarySchema.createV2) }
                try database.setUserVersion(2)
            default:
                throw LibraryError.unsupportedSchemaVersion(current)
            }
            current = try database.userVersion()
        }

        guard current == LibrarySchema.version else {
            throw LibraryError.unsupportedSchemaVersion(current)
        }
    }

    // MARK: - Pins

    public func pinnedCodes() throws -> [ClinicalCode] {
        try readCodes(from: try database.prepare(LibrarySchema.selectPinned))
    }

    public func isPinned(_ code: ClinicalCode) throws -> Bool {
        let statement = try database.prepare("""
        SELECT 1 FROM pins p JOIN saved_codes c ON c.id = p.saved_code_id
         WHERE c.system = :system AND c.code = :code;
        """)
        try statement.bind(code.system.rawValue, to: ":system")
        try statement.bind(code.code, to: ":code")
        return try statement.step()
    }

    @discardableResult
    public func togglePin(_ code: ClinicalCode) throws -> Bool {
        let pinned = try isPinned(code)

        try database.transaction {
            let id = try saveCode(code)
            if pinned {
                let delete = try database.prepare("DELETE FROM pins WHERE saved_code_id = :id;")
                try delete.bind(id, to: ":id")
                try delete.step()
                try database.execute(LibrarySchema.pruneOrphans)
            } else {
                // New pins go to the top; existing sort orders are left alone so
                // a future manual ordering is not disturbed by a later pin.
                let insert = try database.prepare("""
                INSERT INTO pins (saved_code_id, pinned_at, sort_order)
                VALUES (:id, :now, COALESCE((SELECT MIN(sort_order) FROM pins), 0) - 1);
                """)
                try insert.bind(id, to: ":id")
                try insert.bind(Int(Date().timeIntervalSince1970), to: ":now")
                try insert.step()
            }
        }
        return !pinned
    }

    // MARK: - Usage

    public func recordUse(of code: ClinicalCode, format: CopyFormat) throws {
        try database.transaction {
            let id = try saveCode(code)
            let insert = try database.prepare("""
            INSERT INTO usage_events (saved_code_id, used_at, copy_format)
            VALUES (:id, :now, :format);
            """)
            try insert.bind(id, to: ":id")
            try insert.bind(Int(Date().timeIntervalSince1970), to: ":now")
            try insert.bind(format.rawValue, to: ":format")
            try insert.step()
        }
    }

    public func recentCodes(limit: Int) throws -> [ClinicalCode] {
        let statement = try database.prepare(LibrarySchema.selectRecent)
        try statement.bind(limit, to: ":limit")
        return try readCodes(from: statement)
    }

    public func mostUsedCodes(limit: Int) throws -> [ClinicalCode] {
        let statement = try database.prepare(LibrarySchema.selectMostUsed)
        try statement.bind(limit, to: ":limit")
        return try readCodes(from: statement)
    }

    public func usageCount(for code: ClinicalCode) throws -> Int {
        let statement = try database.prepare("""
        SELECT COUNT(u.id) FROM usage_events u
          JOIN saved_codes c ON c.id = u.saved_code_id
         WHERE c.system = :system AND c.code = :code;
        """)
        try statement.bind(code.system.rawValue, to: ":system")
        try statement.bind(code.code, to: ":code")
        guard try statement.step() else { return 0 }
        return statement.int(at: 0)
    }

    // MARK: - Lists

    public func lists() throws -> [CodeList] {
        let statement = try database.prepare(LibrarySchema.selectLists)
        var lists: [CodeList] = []
        while try statement.step() {
            guard let name = statement.string(at: 1) else { continue }
            lists.append(CodeList(
                id: statement.int(at: 0),
                name: name,
                detail: statement.string(at: 2),
                createdAt: Date(timeIntervalSince1970: TimeInterval(statement.int(at: 3))),
                count: statement.int(at: 4)
            ))
        }
        return lists
    }

    @discardableResult
    public func createList(named name: String, detail: String?) throws -> CodeList {
        let now = Int(Date().timeIntervalSince1970)
        let insert = try database.prepare("""
        INSERT INTO lists (name, detail, created_at, sort_order)
        VALUES (:name, :detail, :now,
                COALESCE((SELECT MAX(sort_order) FROM lists), 0) + 1);
        """)
        try insert.bind(name, to: ":name")
        try insert.bind(detail, to: ":detail")
        try insert.bind(now, to: ":now")
        try insert.step()

        guard let created = try lists().last(where: { $0.name == name }) else {
            throw LibraryError.saveFailed(name)
        }
        return created
    }

    public func renameList(_ id: Int, to name: String) throws {
        let update = try database.prepare("UPDATE lists SET name = :name WHERE id = :id;")
        try update.bind(name, to: ":name")
        try update.bind(id, to: ":id")
        try update.step()
    }

    public func deleteList(_ id: Int) throws {
        try database.transaction {
            let delete = try database.prepare("DELETE FROM lists WHERE id = :id;")
            try delete.bind(id, to: ":id")
            try delete.step()
            // Members cascade; the codes themselves may now be leftovers.
            try database.execute(LibrarySchema.pruneOrphans)
        }
    }

    public func codes(inList id: Int) throws -> [ClinicalCode] {
        let statement = try database.prepare(LibrarySchema.selectListMembers)
        try statement.bind(id, to: ":list_id")
        return try readCodes(from: statement)
    }

    public func addCode(_ code: ClinicalCode, toList id: Int) throws {
        try database.transaction {
            let savedID = try saveCode(code)
            let insert = try database.prepare("""
            INSERT INTO list_members (list_id, saved_code_id, sort_order)
            VALUES (:list_id, :code_id,
                    COALESCE((SELECT MAX(sort_order) FROM list_members
                               WHERE list_id = :list_id), 0) + 1)
            ON CONFLICT(list_id, saved_code_id) DO NOTHING;
            """)
            try insert.bind(id, to: ":list_id")
            try insert.bind(savedID, to: ":code_id")
            try insert.step()
        }
    }

    public func removeCode(_ code: ClinicalCode, fromList id: Int) throws {
        try database.transaction {
            let delete = try database.prepare("""
            DELETE FROM list_members
             WHERE list_id = :list_id
               AND saved_code_id IN (SELECT id FROM saved_codes
                                      WHERE system = :system AND code = :code);
            """)
            try delete.bind(id, to: ":list_id")
            try delete.bind(code.system.rawValue, to: ":system")
            try delete.bind(code.code, to: ":code")
            try delete.step()
            try database.execute(LibrarySchema.pruneOrphans)
        }
    }

    // MARK: - Notes

    public func note(for code: ClinicalCode) throws -> String? {
        let statement = try database.prepare(LibrarySchema.selectNote)
        try statement.bind(code.system.rawValue, to: ":system")
        try statement.bind(code.code, to: ":code")
        guard try statement.step() else { return nil }
        return statement.string(at: 0)
    }

    public func setNote(_ body: String, for code: ClinicalCode) throws {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)

        try database.transaction {
            if trimmed.isEmpty {
                let delete = try database.prepare("""
                DELETE FROM notes WHERE saved_code_id IN
                    (SELECT id FROM saved_codes WHERE system = :system AND code = :code);
                """)
                try delete.bind(code.system.rawValue, to: ":system")
                try delete.bind(code.code, to: ":code")
                try delete.step()
                try database.execute(LibrarySchema.pruneOrphans)
                return
            }

            let savedID = try saveCode(code)
            let upsert = try database.prepare(LibrarySchema.upsertNote)
            try upsert.bind(savedID, to: ":id")
            try upsert.bind(trimmed, to: ":body")
            try upsert.bind(Int(Date().timeIntervalSince1970), to: ":now")
            try upsert.step()
        }
    }

    // MARK: - Migration from UserDefaults

    /// Runs once. Anything already in the library means a previous run adopted
    /// the old data, so this must not run again and duplicate it.
    @discardableResult
    public func adoptLegacyData(pinned: [ClinicalCode], recent: [ClinicalCode]) throws -> Bool {
        guard try isEmpty() else { return false }
        guard !pinned.isEmpty || !recent.isEmpty else { return false }

        // Oldest first, so the resulting recency order matches the old list.
        for code in recent.reversed() {
            try recordUse(of: code, format: .codeOnly)
        }
        for code in pinned.reversed() {
            try togglePin(code)
        }
        return true
    }

    public func isEmpty() throws -> Bool {
        let statement = try database.prepare("SELECT COUNT(*) FROM saved_codes;")
        guard try statement.step() else { return true }
        return statement.int(at: 0) == 0
    }

    // MARK: - Private

    /// Inserts or refreshes the hub row and returns its id.
    private func saveCode(_ code: ClinicalCode) throws -> Int {
        let upsert = try database.prepare(LibrarySchema.upsertSavedCode)
        try upsert.bind(code.system.rawValue, to: ":system")
        try upsert.bind(code.code, to: ":code")
        try upsert.bind(code.display, to: ":display")
        try upsert.bind(encodeSynonyms(code.synonyms), to: ":synonyms_json")
        try upsert.bind(code.isBillable.map { $0 ? 1 : 0 }, to: ":is_billable")
        try upsert.bind(Int(Date().timeIntervalSince1970), to: ":now")
        try upsert.step()

        let lookup = try database.prepare(
            "SELECT id FROM saved_codes WHERE system = :system AND code = :code;"
        )
        try lookup.bind(code.system.rawValue, to: ":system")
        try lookup.bind(code.code, to: ":code")
        guard try lookup.step() else { throw LibraryError.saveFailed(code.id) }
        return lookup.int(at: 0)
    }

    private func readCodes(from statement: Statement) throws -> [ClinicalCode] {
        var codes: [ClinicalCode] = []
        while try statement.step() {
            guard let systemRaw = statement.string(at: 0),
                  let system = CodeSystem(rawValue: systemRaw),
                  let code = statement.string(at: 1),
                  let display = statement.string(at: 2)
            else { continue }

            codes.append(ClinicalCode(
                code: code,
                display: display,
                system: system,
                synonyms: decodeSynonyms(statement.string(at: 3)),
                isBillable: statement.optionalBool(at: 4)
            ))
        }
        return codes
    }

    private func encodeSynonyms(_ synonyms: [String]) -> String {
        guard let data = try? JSONEncoder().encode(synonyms),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    private func decodeSynonyms(_ json: String?) -> [String] {
        guard let json, let data = json.data(using: .utf8),
              let synonyms = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return synonyms
    }
}

public enum LibraryError: Error, CustomStringConvertible, Equatable {
    case unsupportedSchemaVersion(Int32)
    case saveFailed(String)

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "Your CodeBar library was written by a newer version (schema \(version))."
        case .saveFailed(let id):
            "Could not save \(id) to the library."
        }
    }
}

extension SQLiteCodeLibrary.Location {
    func path() throws -> String {
        switch self {
        case .inMemory: ":memory:"
        case .file(let url): url.path
        case .applicationSupport: try Self.applicationSupportPath()
        }
    }

    private static func applicationSupportPath() throws -> String {
        let directory = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("CodeBar", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("library.sqlite").path
    }
}
