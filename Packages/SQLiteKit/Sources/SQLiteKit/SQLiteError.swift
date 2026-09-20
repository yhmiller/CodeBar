import Foundation
import SQLite3

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

public enum StoreError: Error, CustomStringConvertible, Equatable {
    case unsupportedSchemaVersion(Int32)

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "Database schema version \(version) is newer than this build supports."
        }
    }
}
