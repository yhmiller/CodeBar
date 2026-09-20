import CodeCore
import Foundation
import SQLiteKit
import Testing
@testable import CodeLibrary

@Suite("Stored abbreviations")
struct AbbreviationStoreTests {

    private func library() throws -> SQLiteCodeLibrary {
        try SQLiteCodeLibrary(location: .inMemory)
    }

    @Test("should return nothing before anything is added")
    func startsEmpty() async throws {
        #expect(try await library().abbreviations().isEmpty)
    }

    @Test("should store an abbreviation the user added")
    func storesOne() async throws {
        let library = try library()

        try await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin"))

        #expect(try await library.abbreviations() == [
            Abbreviation(term: "pcn", expansion: "penicillin")
        ])
    }

    @Test("should replace the expansion when the same term is added again")
    func replacesOnSameTerm() async throws {
        let library = try library()
        try await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin"))

        try await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin G"))

        #expect(try await library.abbreviations().map(\.expansion) == ["penicillin G"])
    }

    @Test("should treat a term typed in a different case as the same entry")
    func replacesRegardlessOfCase() async throws {
        let library = try library()
        try await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin"))

        try await library.saveAbbreviation(Abbreviation(term: "PCN", expansion: "penicillin G"))

        #expect(try await library.abbreviations().count == 1)
    }

    @Test("should remove an abbreviation by term")
    func removesOne() async throws {
        let library = try library()
        try await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin"))

        try await library.removeAbbreviation(term: "pcn")

        #expect(try await library.abbreviations().isEmpty)
    }

    @Test("should remove an entry when the term is given in a different case")
    func removesRegardlessOfCase() async throws {
        let library = try library()
        try await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin"))

        try await library.removeAbbreviation(term: "PCN")

        #expect(try await library.abbreviations().isEmpty)
    }

    @Test("should refuse an entry with no expansion to search for")
    func refusesUnusableEntry() async throws {
        let library = try library()

        try await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "  "))

        #expect(try await library.abbreviations().isEmpty)
    }

    @Test("should list abbreviations alphabetically")
    func listsAlphabetically() async throws {
        let library = try library()
        try await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin"))
        try await library.saveAbbreviation(Abbreviation(term: "abx", expansion: "antibiotic"))

        #expect(try await library.abbreviations().map(\.term) == ["abx", "pcn"])
    }

    @Test("should migrate a v2 library forward without losing what is in it")
    func migratesV2ToV3() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codebar-v2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.sqlite")

        let database = try Database(path: url.path)
        try database.execute(LibrarySchema.createV1 + LibrarySchema.createV2)
        try database.setUserVersion(2)

        let diabetes = ClinicalCode(
            code: "E11.9", display: "Type 2 diabetes mellitus without complications",
            system: .icd10cm, isBillable: true
        )
        let before = try SQLiteCodeLibrary(location: .file(url))
        try await before.togglePin(diabetes)
        try await before.setNote("Ours", for: diabetes)

        let after = try SQLiteCodeLibrary(location: .file(url))
        try await after.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin"))

        #expect(try await after.pinnedCodes() == [diabetes])
        #expect(try await after.note(for: diabetes) == "Ours")
        #expect(try await after.abbreviations().count == 1)
    }
}
