import CodeCore
import Foundation
import SQLiteKit
import Testing
@testable import CodeLibrary

@Suite("Lists and notes")
struct ListsAndNotesTests {

    private func library() throws -> SQLiteCodeLibrary {
        try SQLiteCodeLibrary(location: .inMemory)
    }

    private let diabetes = ClinicalCode(
        code: "E11.9", display: "Type 2 diabetes mellitus without complications",
        system: .icd10cm, isBillable: true
    )
    private let asthma = ClinicalCode(
        code: "J45.909", display: "Unspecified asthma, uncomplicated", system: .icd10cm
    )

    // MARK: - Lists

    @Test("should start with no lists")
    func startsEmpty() async throws {
        #expect(try await library().lists().isEmpty)
    }

    @Test("should create a list")
    func createsAList() async throws {
        let library = try library()
        try await library.createList(named: "Diabetes clinic", detail: nil)
        #expect(try await library.lists().map(\.name) == ["Diabetes clinic"])
    }

    @Test("should report a new list as empty")
    func newListIsEmpty() async throws {
        let library = try library()
        let list = try await library.createList(named: "Clinic", detail: nil)
        #expect(list.count == 0)
    }

    @Test("should add a code to a list")
    func addsACode() async throws {
        let library = try library()
        let list = try await library.createList(named: "Clinic", detail: nil)
        try await library.addCode(diabetes, toList: list.id)
        #expect(try await library.codes(inList: list.id).map(\.code) == ["E11.9"])
    }

    @Test("should not add the same code twice")
    func addingTwiceIsIdempotent() async throws {
        let library = try library()
        let list = try await library.createList(named: "Clinic", detail: nil)
        try await library.addCode(diabetes, toList: list.id)
        try await library.addCode(diabetes, toList: list.id)
        #expect(try await library.codes(inList: list.id).count == 1)
    }

    @Test("should keep the order codes were added in")
    func preservesOrder() async throws {
        let library = try library()
        let list = try await library.createList(named: "Clinic", detail: nil)
        try await library.addCode(diabetes, toList: list.id)
        try await library.addCode(asthma, toList: list.id)
        #expect(try await library.codes(inList: list.id).map(\.code) == ["E11.9", "J45.909"])
    }

    @Test("should count a list's members")
    func countsMembers() async throws {
        let library = try library()
        let list = try await library.createList(named: "Clinic", detail: nil)
        try await library.addCode(diabetes, toList: list.id)
        #expect(try await library.lists().first?.count == 1)
    }

    @Test("should remove a code from a list")
    func removesACode() async throws {
        let library = try library()
        let list = try await library.createList(named: "Clinic", detail: nil)
        try await library.addCode(diabetes, toList: list.id)
        try await library.removeCode(diabetes, fromList: list.id)
        #expect(try await library.codes(inList: list.id).isEmpty)
    }

    @Test("should rename a list")
    func renamesAList() async throws {
        let library = try library()
        let list = try await library.createList(named: "Old", detail: nil)
        try await library.renameList(list.id, to: "New")
        #expect(try await library.lists().first?.name == "New")
    }

    @Test("should delete a list")
    func deletesAList() async throws {
        let library = try library()
        let list = try await library.createList(named: "Clinic", detail: nil)
        try await library.deleteList(list.id)
        #expect(try await library.lists().isEmpty)
    }

    @Test("should not touch a pinned code when its list is deleted")
    func deletingAListKeepsPins() async throws {
        let library = try library()
        let list = try await library.createList(named: "Clinic", detail: nil)
        try await library.addCode(diabetes, toList: list.id)
        try await library.togglePin(diabetes)

        try await library.deleteList(list.id)

        #expect(try await library.isPinned(diabetes))
    }

    // MARK: - Notes

    @Test("should report no note for an unannotated code")
    func noNoteInitially() async throws {
        #expect(try await library().note(for: diabetes) == nil)
    }

    @Test("should store a note against a code")
    func storesANote() async throws {
        let library = try library()
        try await library.setNote("Our clinic codes new diagnoses here", for: diabetes)
        #expect(try await library.note(for: diabetes) == "Our clinic codes new diagnoses here")
    }

    @Test("should replace a note rather than append to it")
    func replacesANote() async throws {
        let library = try library()
        try await library.setNote("First", for: diabetes)
        try await library.setNote("Second", for: diabetes)
        #expect(try await library.note(for: diabetes) == "Second")
    }

    @Test("should trim surrounding whitespace from a note")
    func trimsWhitespace() async throws {
        let library = try library()
        try await library.setNote("  spaced  ", for: diabetes)
        #expect(try await library.note(for: diabetes) == "spaced")
    }

    @Test("should delete a note set to empty")
    func emptyNoteDeletes() async throws {
        let library = try library()
        try await library.setNote("Something", for: diabetes)
        try await library.setNote("   ", for: diabetes)
        #expect(try await library.note(for: diabetes) == nil)
    }

    @Test("should keep a note when the code is unpinned")
    func noteSurvivesUnpin() async throws {
        // Unpinning prunes leftovers, and a note is a reason to keep the row.
        let library = try library()
        try await library.togglePin(diabetes)
        try await library.setNote("Keep me", for: diabetes)

        try await library.togglePin(diabetes)

        #expect(try await library.note(for: diabetes) == "Keep me")
    }

    @Test("should keep a note when the code is removed from a list")
    func noteSurvivesListRemoval() async throws {
        let library = try library()
        let list = try await library.createList(named: "Clinic", detail: nil)
        try await library.addCode(diabetes, toList: list.id)
        try await library.setNote("Keep me", for: diabetes)

        try await library.removeCode(diabetes, fromList: list.id)

        #expect(try await library.note(for: diabetes) == "Keep me")
    }

    // MARK: - Migration

    @Test("should migrate a v1 library forward without losing pins")
    func migratesV1ToV2() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codebar-v1-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.sqlite")

        // A v1 library: the hub, pins and usage, but no lists, notes or
        // abbreviations.
        let database = try Database(path: url.path)
        try database.execute(LibrarySchema.createV1)
        try database.setUserVersion(1)

        let library = try SQLiteCodeLibrary(location: .file(url))
        try await library.togglePin(diabetes)

        let hasNoLists = try await library.lists().isEmpty
        let keptPin = try await library.isPinned(diabetes)
        #expect(hasNoLists && keptPin)
    }
}
