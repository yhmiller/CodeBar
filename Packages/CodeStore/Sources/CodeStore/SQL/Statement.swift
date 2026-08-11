import Foundation
import SQLite3

/// Tells SQLite to copy a bound value immediately, so the caller's Swift string
/// does not need to outlive the bind call.
private var sqliteTransient: sqlite3_destructor_type {
    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

/// A prepared statement with checked binding and stepping.
///
/// Not `Sendable` by design — instances are created and consumed entirely
/// inside `SQLiteCodeStore`'s actor isolation.
final class Statement {
    private var handle: OpaquePointer?
    private let databaseHandle: OpaquePointer?
    private let sql: String

    init(database: OpaquePointer?, sql: String) throws {
        var handle: OpaquePointer?
        let result = sqlite3_prepare_v2(database, sql, -1, &handle, nil)
        guard result == SQLITE_OK, let handle else {
            throw SQLiteError(code: result, message: Self.lastMessage(database), sql: sql)
        }
        self.handle = handle
        self.databaseHandle = database
        self.sql = sql
    }

    deinit {
        sqlite3_finalize(handle)
    }

    // MARK: - Binding

    func bind(_ value: String, to name: String) throws {
        try check(sqlite3_bind_text(handle, try index(of: name), value, -1, sqliteTransient))
    }

    func bind(_ value: String?, to name: String) throws {
        if let value {
            try bind(value, to: name)
        } else {
            try check(sqlite3_bind_null(handle, try index(of: name)))
        }
    }

    func bind(_ value: Int, to name: String) throws {
        try check(sqlite3_bind_int64(handle, try index(of: name), Int64(value)))
    }

    private func index(of name: String) throws -> Int32 {
        let index = sqlite3_bind_parameter_index(handle, name)
        guard index > 0 else {
            throw SQLiteError(code: SQLITE_RANGE, message: "no such bind parameter \(name)", sql: sql)
        }
        return index
    }

    // MARK: - Executing

    /// Advances the statement. Returns `true` when a row is available.
    @discardableResult
    func step() throws -> Bool {
        let result = sqlite3_step(handle)
        switch result {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw SQLiteError(code: result, message: Self.lastMessage(databaseHandle), sql: sql)
        }
    }

    /// Rewinds for reuse. Return codes are intentionally ignored: `sqlite3_reset`
    /// re-reports the error from the previous execution, which `step()` has
    /// already thrown.
    func reset() {
        sqlite3_reset(handle)
        sqlite3_clear_bindings(handle)
    }

    // MARK: - Reading

    func string(at column: Int32) -> String? {
        guard let text = sqlite3_column_text(handle, column) else { return nil }
        return String(cString: text)
    }

    func int(at column: Int32) -> Int {
        Int(sqlite3_column_int64(handle, column))
    }

    // MARK: - Errors

    private func check(_ result: Int32) throws {
        guard result == SQLITE_OK else {
            throw SQLiteError(code: result, message: Self.lastMessage(databaseHandle), sql: sql)
        }
    }

    private static func lastMessage(_ database: OpaquePointer?) -> String {
        guard let database, let message = sqlite3_errmsg(database) else { return "unknown error" }
        return String(cString: message)
    }
}
