import Foundation
import Testing
@testable import SQLiteKit

@Suite("SQLiteKit")
struct SQLiteKitTests {

    private func database() throws -> Database {
        let database = try Database(path: ":memory:")
        try database.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT, n INTEGER);")
        return database
    }

    @Test("should round-trip a bound string")
    func roundTripsString() throws {
        let database = try database()
        let insert = try database.prepare("INSERT INTO t (name) VALUES (:name);")
        try insert.bind("hello", to: ":name")
        try insert.step()

        let select = try database.prepare("SELECT name FROM t;")
        #expect(try select.step() && select.string(at: 0) == "hello")
    }

    @Test("should round-trip a bound integer")
    func roundTripsInt() throws {
        let database = try database()
        let insert = try database.prepare("INSERT INTO t (n) VALUES (:n);")
        try insert.bind(42, to: ":n")
        try insert.step()

        let select = try database.prepare("SELECT n FROM t;")
        #expect(try select.step() && select.int(at: 0) == 42)
    }

    @Test("should distinguish a NULL from a zero")
    func distinguishesNullFromZero() throws {
        let database = try database()
        let insert = try database.prepare("INSERT INTO t (n) VALUES (:n);")
        try insert.bind(Int?.none, to: ":n")
        try insert.step()

        let select = try database.prepare("SELECT n FROM t;")
        #expect(try select.step() && select.optionalBool(at: 0) == nil)
    }

    @Test("should report false for a stored zero")
    func readsStoredFalse() throws {
        let database = try database()
        let insert = try database.prepare("INSERT INTO t (n) VALUES (:n);")
        try insert.bind(0, to: ":n")
        try insert.step()

        let select = try database.prepare("SELECT n FROM t;")
        #expect(try select.step() && select.optionalBool(at: 0) == false)
    }

    @Test("should throw on invalid SQL rather than failing silently")
    func throwsOnInvalidSQL() throws {
        let database = try database()
        #expect(throws: SQLiteError.self) {
            _ = try database.prepare("SELECT nope FROM missing;")
        }
    }

    @Test("should throw when binding an unknown parameter")
    func throwsOnUnknownParameter() throws {
        let database = try database()
        let statement = try database.prepare("INSERT INTO t (name) VALUES (:name);")
        #expect(throws: SQLiteError.self) {
            try statement.bind("x", to: ":wrong")
        }
    }

    @Test("should roll back a transaction that throws")
    func rollsBackOnThrow() throws {
        let database = try database()
        struct Failure: Error {}

        try? database.transaction {
            try database.execute("INSERT INTO t (name) VALUES ('a');")
            throw Failure()
        }

        let count = try database.prepare("SELECT COUNT(*) FROM t;")
        #expect(try count.step() && count.int(at: 0) == 0)
    }

    @Test("should commit a transaction that succeeds")
    func commitsOnSuccess() throws {
        let database = try database()
        try database.transaction {
            try database.execute("INSERT INTO t (name) VALUES ('a');")
        }

        let count = try database.prepare("SELECT COUNT(*) FROM t;")
        #expect(try count.step() && count.int(at: 0) == 1)
    }

    @Test("should let a statement be reused after reset")
    func reusesAfterReset() throws {
        let database = try database()
        let insert = try database.prepare("INSERT INTO t (name) VALUES (:name);")
        for name in ["a", "b", "c"] {
            insert.reset()
            try insert.bind(name, to: ":name")
            try insert.step()
        }

        let count = try database.prepare("SELECT COUNT(*) FROM t;")
        #expect(try count.step() && count.int(at: 0) == 3)
    }

    @Test("should report the user version it was given")
    func roundTripsUserVersion() throws {
        let database = try database()
        try database.setUserVersion(7)
        #expect(try database.userVersion() == 7)
    }

    @Test("should know which tables exist")
    func reportsExistingTable() throws {
        #expect(try database().tableExists("t"))
    }

    @Test("should know which tables do not exist")
    func reportsMissingTable() throws {
        #expect(try database().tableExists("nope") == false)
    }

    @Test("should count the rows a statement changed")
    func countsChanges() throws {
        let database = try database()
        try database.execute("INSERT INTO t (name) VALUES ('a'), ('b');")
        try database.execute("DELETE FROM t;")
        #expect(database.changeCount == 2)
    }
}
