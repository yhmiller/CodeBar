import Foundation
import SQLite3

/// Tells SQLite to make its own internal copy of a bound string immediately,
/// so we don't have to worry about the lifetime of the Swift string we pass in.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Local, on-device full-text search over clinical code sets (ICD-10-CM, LOINC,
/// SNOMED CT, CPT). Backed by SQLite FTS5 so it scales from a few hundred seed
/// codes up to full official code sets (tens to hundreds of thousands of rows)
/// without changing the query code.
final class CodeDatabase {
    static let shared = CodeDatabase()
    private var db: OpaquePointer?

    private init() {
        openDatabase()
        createTableIfNeeded()
    }

    private var dbURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodeBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("codes.sqlite")
    }

    private func openDatabase() {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            print("CodeBar: unable to open database at \(dbURL.path)")
        }
    }

    private func createTableIfNeeded() {
        exec("""
        CREATE VIRTUAL TABLE IF NOT EXISTS codes_fts USING fts5(
            code, display, synonyms, system UNINDEXED, tokenize='porter unicode61'
        );
        """)
    }

    private func exec(_ sql: String) {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            print("CodeBar SQLite error: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    // MARK: - Loading data

    /// Loads the bundled starter ICD-10-CM sample on first launch only.
    /// Safe to call every launch — it no-ops once the table has rows.
    func loadSeedDataIfNeeded() {
        var countStmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM codes_fts", -1, &countStmt, nil)
        defer { sqlite3_finalize(countStmt) }
        var count: Int32 = 0
        if sqlite3_step(countStmt) == SQLITE_ROW {
            count = sqlite3_column_int(countStmt, 0)
        }
        guard count == 0 else { return }

        guard let url = Bundle.main.url(forResource: "seed_icd10_sample", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let codes = try? JSONDecoder().decode([ClinicalCode].self, from: data) else {
            print("CodeBar: seed_icd10_sample.json not found or failed to decode")
            return
        }
        importCodes(codes)
    }

    /// Bulk import — used both for the initial seed and for "Import Code Set…"
    /// (a JSON file produced by one of the Scripts/import_*.py converters).
    func importCodes(_ codes: [ClinicalCode]) {
        exec("BEGIN TRANSACTION;")
        let insertSQL = "INSERT INTO codes_fts (code, display, synonyms, system) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil)
        for c in codes {
            sqlite3_reset(stmt)
            bindText(stmt, 1, c.code)
            bindText(stmt, 2, c.display)
            bindText(stmt, 3, c.synonyms.joined(separator: " "))
            bindText(stmt, 4, c.system.rawValue)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        exec("COMMIT;")
    }

    private func bindText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String) {
        _ = value.withCString { cString in
            sqlite3_bind_text(stmt, index, cString, -1, SQLITE_TRANSIENT)
        }
    }

    // MARK: - Search

    /// Two-pass search: exact/prefix code matches first (typing "E11" should
    /// surface E11.x immediately), then full-text prefix matches on the
    /// display text and synonyms, deduplicated and capped at 30 results.
    func search(_ query: String) -> [ClinicalCode] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var results: [ClinicalCode] = []
        var seenIDs = Set<String>()

        // Pass 1: code prefix match, e.g. "E11" -> E11.9, E11.21, ...
        let codePrefix = trimmed.uppercased()
        do {
            let sql = "SELECT code, display, synonyms, system FROM codes_fts WHERE code LIKE ? LIMIT 10;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            bindText(stmt, 1, codePrefix + "%")
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let item = rowToCode(stmt), !seenIDs.contains(item.id) {
                    results.append(item)
                    seenIDs.insert(item.id)
                }
            }
            sqlite3_finalize(stmt)
        }

        // Pass 2: full-text prefix match on display text + synonyms
        let tokens = trimmed
            .split(separator: " ")
            .map { $0.replacingOccurrences(of: "\"", with: "") }
            .filter { !$0.isEmpty }
            .map { "\($0)*" }
        if !tokens.isEmpty {
            let matchQuery = "{display synonyms}: " + tokens.joined(separator: " ")
            let sql = """
            SELECT code, display, synonyms, system FROM codes_fts
            WHERE codes_fts MATCH ?
            ORDER BY bm25(codes_fts) LIMIT 30;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                bindText(stmt, 1, matchQuery)
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let item = rowToCode(stmt), !seenIDs.contains(item.id) {
                        results.append(item)
                        seenIDs.insert(item.id)
                    }
                }
            }
            sqlite3_finalize(stmt)
        }

        return Array(results.prefix(30))
    }

    private func rowToCode(_ stmt: OpaquePointer?) -> ClinicalCode? {
        guard let codeC = sqlite3_column_text(stmt, 0),
              let displayC = sqlite3_column_text(stmt, 1),
              let synC = sqlite3_column_text(stmt, 2),
              let sysC = sqlite3_column_text(stmt, 3) else { return nil }
        let code = String(cString: codeC)
        let display = String(cString: displayC)
        let syn = String(cString: synC)
        let sysRaw = String(cString: sysC)
        guard let system = ClinicalCode.CodeSystem(rawValue: sysRaw) else { return nil }
        return ClinicalCode(
            code: code,
            display: display,
            system: system,
            synonyms: syn.split(separator: " ").map(String.init)
        )
    }
}
