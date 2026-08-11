import CodeCore

/// Stands in when `library.sqlite` could not be opened.
///
/// Search still works without a library; only pins and history are lost. A
/// no-op keeps that failure contained rather than making the panel unusable.
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
}
