public protocol CodeLibraryStoring: Sendable {

    // MARK: - Pins

    func pinnedCodes() async throws -> [ClinicalCode]
    func isPinned(_ code: ClinicalCode) async throws -> Bool
    @discardableResult
    func togglePin(_ code: ClinicalCode) async throws -> Bool

    // MARK: - Usage

    func recordUse(of code: ClinicalCode, format: CopyFormat) async throws
    func recentCodes(limit: Int) async throws -> [ClinicalCode]
    func mostUsedCodes(limit: Int) async throws -> [ClinicalCode]
    func usageCount(for code: ClinicalCode) async throws -> Int

    // MARK: - Lists

    func lists() async throws -> [CodeList]
    @discardableResult
    func createList(named name: String, detail: String?) async throws -> CodeList
    func renameList(_ id: Int, to name: String) async throws
    func deleteList(_ id: Int) async throws
    func codes(inList id: Int) async throws -> [ClinicalCode]
    func addCode(_ code: ClinicalCode, toList id: Int) async throws
    func removeCode(_ code: ClinicalCode, fromList id: Int) async throws

    // MARK: - Notes

    func note(for code: ClinicalCode) async throws -> String?
    func setNote(_ body: String, for code: ClinicalCode) async throws

    // MARK: - Abbreviations

    func abbreviations() async throws -> [Abbreviation]
    func saveAbbreviation(_ abbreviation: Abbreviation) async throws
    func removeAbbreviation(term: String) async throws

    // MARK: - Migration

    @discardableResult
    func adoptLegacyData(pinned: [ClinicalCode], recent: [ClinicalCode]) async throws -> Bool
}
