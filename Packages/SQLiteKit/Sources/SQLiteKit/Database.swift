import Foundation
import SQLite3

private let BUSY_TIMEOUT_MS = 5_000

public final class Database {
    private var handle: OpaquePointer?

    public init(path: String) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        let result = sqlite3_open_v2(path, &handle, flags, nil)
        guard result == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unable to open \(path)"
            sqlite3_close_v2(handle)
            throw SQLiteError(code: result, message: message, sql: nil)
        }
        self.handle = handle
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    public func configure() throws {
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA synchronous = NORMAL;")
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA busy_timeout = \(BUSY_TIMEOUT_MS);")
    }

    // MARK: - Executing

    public func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(handle, sql, nil, nil, &errorPointer)
        defer { sqlite3_free(errorPointer) }
        guard result == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? "unknown error"
            throw SQLiteError(code: result, message: message, sql: sql)
        }
    }

    public func prepare(_ sql: String) throws -> Statement {
        try Statement(database: handle, sql: sql)
    }

    public func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE;")
        do {
            let value = try body()
            try execute("COMMIT;")
            return value
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public var changeCount: Int {
        Int(sqlite3_changes64(handle))
    }

    // MARK: - Schema introspection

    public func userVersion() throws -> Int32 {
        let statement = try prepare("PRAGMA user_version;")
        guard try statement.step() else { return 0 }
        return Int32(statement.int(at: 0))
    }

    public func setUserVersion(_ version: Int32) throws {
        try execute("PRAGMA user_version = \(version);")
    }

    public func tableExists(_ name: String) throws -> Bool {
        let statement = try prepare("SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = :name;")
        try statement.bind(name, to: ":name")
        return try statement.step()
    }
}
