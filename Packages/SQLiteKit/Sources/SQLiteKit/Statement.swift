import Foundation
import SQLite3

private var sqliteTransient: sqlite3_destructor_type {
    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

public final class Statement {
    private var handle: OpaquePointer?
    private let databaseHandle: OpaquePointer?
    private let sql: String

    public init(database: OpaquePointer?, sql: String) throws {
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

    public func bind(_ value: String, to name: String) throws {
        try check(sqlite3_bind_text(handle, try index(of: name), value, -1, sqliteTransient))
    }

    public func bind(_ value: String?, to name: String) throws {
        if let value {
            try bind(value, to: name)
        } else {
            try check(sqlite3_bind_null(handle, try index(of: name)))
        }
    }

    public func bind(_ value: Int, to name: String) throws {
        try check(sqlite3_bind_int64(handle, try index(of: name), Int64(value)))
    }

    public func bind(_ value: Int?, to name: String) throws {
        if let value {
            try bind(value, to: name)
        } else {
            try check(sqlite3_bind_null(handle, try index(of: name)))
        }
    }

    private func index(of name: String) throws -> Int32 {
        let index = sqlite3_bind_parameter_index(handle, name)
        guard index > 0 else {
            throw SQLiteError(code: SQLITE_RANGE, message: "no such bind parameter \(name)", sql: sql)
        }
        return index
    }

    // MARK: - Executing

    @discardableResult
    public func step() throws -> Bool {
        let result = sqlite3_step(handle)
        switch result {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw SQLiteError(code: result, message: Self.lastMessage(databaseHandle), sql: sql)
        }
    }

    public func reset() {
        sqlite3_reset(handle)
        sqlite3_clear_bindings(handle)
    }

    // MARK: - Reading

    public func string(at column: Int32) -> String? {
        guard let text = sqlite3_column_text(handle, column) else { return nil }
        return String(cString: text)
    }

    public func int(at column: Int32) -> Int {
        Int(sqlite3_column_int64(handle, column))
    }

    public func optionalBool(at column: Int32) -> Bool? {
        guard sqlite3_column_type(handle, column) != SQLITE_NULL else { return nil }
        return sqlite3_column_int64(handle, column) != 0
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
