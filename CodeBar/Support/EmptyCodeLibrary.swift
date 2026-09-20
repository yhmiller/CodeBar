import CodeCore
import Foundation

struct EmptyCodeLibrary: CodeLibraryStoring {
    func pinnedCodes() async throws -> [ClinicalCode] { [] }
    func isPinned(_ code: ClinicalCode) async throws -> Bool { false }
    @discardableResult
    func togglePin(_ code: ClinicalCode) async throws -> Bool { false }
    func recordUse(of code: ClinicalCode, format: CopyFormat) async throws {}
    func recentCodes(limit: Int) async throws -> [ClinicalCode] { [] }
    func mostUsedCodes(limit: Int) async throws -> [ClinicalCode] { [] }
    func usageCount(for code: ClinicalCode) async throws -> Int { 0 }
    @discardableResult
    func adoptLegacyData(pinned: [ClinicalCode], recent: [ClinicalCode]) async throws -> Bool { false }

    func lists() async throws -> [CodeList] { [] }
    @discardableResult
    func createList(named name: String, detail: String?) async throws -> CodeList {
        CodeList(id: 0, name: name, detail: detail, createdAt: Date(), count: 0)
    }
    func renameList(_ id: Int, to name: String) async throws {}
    func deleteList(_ id: Int) async throws {}
    func codes(inList id: Int) async throws -> [ClinicalCode] { [] }
    func addCode(_ code: ClinicalCode, toList id: Int) async throws {}
    func removeCode(_ code: ClinicalCode, fromList id: Int) async throws {}
    func note(for code: ClinicalCode) async throws -> String? { nil }
    func setNote(_ body: String, for code: ClinicalCode) async throws {}

    func abbreviations() async throws -> [Abbreviation] { [] }
    func saveAbbreviation(_ abbreviation: Abbreviation) async throws {}
    func removeAbbreviation(term: String) async throws {}
}
