import Foundation
import SQLite3

/// A failed SQLite call, carrying the statement that caused it.
///
/// Every `sqlite3_*` return code in this module is checked and surfaced as one
/// of these. The previous implementation discarded them and `print`ed at best,
/// which turned a failed open into an app that silently returned no results.
public struct SQLiteError: Error, CustomStringConvertible, Equatable {
    public let code: Int32
    public let message: String
    public let sql: String?

    public var description: String {
        var text = "SQLite error \(code): \(message)"
        if let sql {
            text += "\n  in: \(sql.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        return text
    }
}

/// Failures above the SQL layer.
public enum StoreError: Error, CustomStringConvertible, Equatable {
    /// The database was written by a newer build of CodeBar.
    case unsupportedSchemaVersion(Int32)

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "Database schema version \(version) is newer than this build supports."
        }
    }
}
