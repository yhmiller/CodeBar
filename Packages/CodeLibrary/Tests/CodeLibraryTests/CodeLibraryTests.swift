import CodeCore
import Foundation
import SQLiteKit
import Testing
@testable import CodeLibrary

@Suite("CodeLibrary")
struct CodeLibraryTests {

    private func library() throws -> SQLiteCodeLibrary {
        try SQLiteCodeLibrary(location: .inMemory)
    }

    private let diabetes = ClinicalCode(
        code: "E11.9", display: "Type 2 diabetes mellitus without complications",
        system: .icd10cm, synonyms: ["T2DM"], isBillable: true
    )
    private let asthma = ClinicalCode(
        code: "J45.909", display: "Unspecified asthma, uncomplicated",
        system: .icd10cm, isBillable: true
    )
    private let header = ClinicalCode(
        code: "E11", display: "Type 2 diabetes mellitus", system: .icd10cm, isBillable: false
    )

    // MARK: - Pins

    @Test("should start with nothing pinned")
    func startsEmpty() async throws {
        #expect(try await library().pinnedCodes().isEmpty)
    }

    @Test("should pin a code")
    func pinsACode() async throws {
        let library = try library()
        try await library.togglePin(diabetes)
        #expect(try await library.isPinned(diabetes))
    }

    @Test("should report the resulting state when toggling")
    func toggleReportsNewState() async throws {
        #expect(try await library().togglePin(diabetes) == true)
    }

    @Test("should unpin a code that was pinned")
    func unpinsACode() async throws {
        let library = try library()
        try await library.togglePin(diabetes)
        try await library.togglePin(diabetes)
        #expect(try await library.isPinned(diabetes) == false)
    }

    @Test("should put the most recently pinned code first")
    func newestPinFirst() async throws {
        let library = try library()
        try await library.togglePin(diabetes)
        try await library.togglePin(asthma)
        #expect(try await library.pinnedCodes().first?.code == "J45.909")
    }

    @Test("should keep billability on a pinned code")
    func pinKeepsBillability() async throws {
        let library = try library()
        try await library.togglePin(header)
        #expect(try await library.pinnedCodes().first?.isBillable == false)
    }

    @Test("should keep synonyms on a pinned code")
    func pinKeepsSynonyms() async throws {
        let library = try library()
        try await library.togglePin(diabetes)
        #expect(try await library.pinnedCodes().first?.synonyms == ["T2DM"])
    }

    // MARK: - Usage

    @Test("should record a use")
    func recordsUse() async throws {
        let library = try library()
        try await library.recordUse(of: diabetes, format: .codeOnly)
        #expect(try await library.usageCount(for: diabetes) == 1)
    }

    @Test("should keep every use rather than only the latest")
    func keepsFullHistory() async throws {
        let library = try library()
        for _ in 0..<5 {
            try await library.recordUse(of: diabetes, format: .codeOnly)
        }
        #expect(try await library.usageCount(for: diabetes) == 5)
    }

    @Test("should list a used code as recent")
    func listsRecent() async throws {
        let library = try library()
        try await library.recordUse(of: diabetes, format: .codeOnly)
        #expect(try await library.recentCodes(limit: 8).first?.code == "E11.9")
    }

    @Test("should list each code once in recents however often it was used")
    func recentsAreDistinct() async throws {
        let library = try library()
        try await library.recordUse(of: diabetes, format: .codeOnly)
        try await library.recordUse(of: diabetes, format: .codeOnly)
        #expect(try await library.recentCodes(limit: 8).count == 1)
    }

    @Test("should leave pinned codes out of recents")
    func recentsExcludePinned() async throws {
        let library = try library()
        try await library.recordUse(of: diabetes, format: .codeOnly)
        try await library.togglePin(diabetes)
        #expect(try await library.recentCodes(limit: 8).isEmpty)
    }

    @Test("should rank the most used code first")
    func ranksByFrequency() async throws {
        let library = try library()
        try await library.recordUse(of: asthma, format: .codeOnly)
        for _ in 0..<3 {
            try await library.recordUse(of: diabetes, format: .codeOnly)
        }
        #expect(try await library.mostUsedCodes(limit: 8).first?.code == "E11.9")
    }

    @Test("should honour the requested limit")
    func honoursLimit() async throws {
        let library = try library()
        for index in 0..<10 {
            try await library.recordUse(
                of: ClinicalCode(code: "X\(index)", display: "Code \(index)", system: .icd10cm),
                format: .codeOnly
            )
        }
        #expect(try await library.recentCodes(limit: 3).count == 3)
    }

    // MARK: - Retired codes

    @Test("should keep a pinned code's description after the code set drops it")
    func survivesCodeSetRemoval() async throws {
        // The library never consults the index, so a code retired by the
        // publisher keeps its snapshot here and stays readable.
        let library = try library()
        try await library.togglePin(diabetes)

        #expect(try await library.pinnedCodes().first?.display
                == "Type 2 diabetes mellitus without complications")
    }

    @Test("should refresh a stored description when the code is used again")
    func refreshesSnapshot() async throws {
        let library = try library()
        try await library.togglePin(diabetes)

        let revised = ClinicalCode(code: "E11.9", display: "Revised wording",
                                   system: .icd10cm, isBillable: true)
        try await library.recordUse(of: revised, format: .codeOnly)

        #expect(try await library.pinnedCodes().first?.display == "Revised wording")
    }

    // MARK: - Housekeeping

    @Test("should forget a code that was unpinned and never used")
    func prunesOrphans() async throws {
        let library = try library()
        try await library.togglePin(diabetes)
        try await library.togglePin(diabetes)
        #expect(try await library.isEmpty())
    }

    @Test("should keep a used code after it is unpinned")
    func keepsUsedCodeAfterUnpin() async throws {
        let library = try library()
        try await library.recordUse(of: diabetes, format: .codeOnly)
        try await library.togglePin(diabetes)
        try await library.togglePin(diabetes)
        #expect(try await library.usageCount(for: diabetes) == 1)
    }

    // MARK: - Adopting the old UserDefaults data

    @Test("should adopt pins held before the library existed")
    func adoptsLegacyPins() async throws {
        let library = try library()
        try await library.adoptLegacyData(pinned: [diabetes], recent: [])
        #expect(try await library.isPinned(diabetes))
    }

    @Test("should adopt recents held before the library existed")
    func adoptsLegacyRecents() async throws {
        let library = try library()
        try await library.adoptLegacyData(pinned: [], recent: [asthma])
        #expect(try await library.recentCodes(limit: 8).first?.code == "J45.909")
    }

    @Test("should preserve the old recency order when adopting")
    func adoptionPreservesOrder() async throws {
        let library = try library()
        try await library.adoptLegacyData(pinned: [], recent: [diabetes, asthma])
        #expect(try await library.recentCodes(limit: 8).map(\.code) == ["E11.9", "J45.909"])
    }

    @Test("should not adopt twice and duplicate the data")
    func adoptsOnlyOnce() async throws {
        let library = try library()
        try await library.adoptLegacyData(pinned: [diabetes], recent: [])

        #expect(try await library.adoptLegacyData(pinned: [diabetes], recent: []) == false)
    }

    @Test("should report doing nothing when there is nothing to adopt")
    func adoptingNothingReportsFalse() async throws {
        #expect(try await library().adoptLegacyData(pinned: [], recent: []) == false)
    }

    @Test("should refuse a library written by a newer schema")
    func rejectsNewerSchema() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codebar-lib-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.sqlite")

        _ = try SQLiteCodeLibrary(location: .file(url))
        let database = try Database(path: url.path)
        try database.setUserVersion(LibrarySchema.version + 1)

        #expect(throws: LibraryError.unsupportedSchemaVersion(LibrarySchema.version + 1)) {
            _ = try SQLiteCodeLibrary(location: .file(url))
        }
    }
}
