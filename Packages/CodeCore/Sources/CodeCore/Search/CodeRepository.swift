public protocol CodeRepository: Sendable {

    func search(_ query: SearchQuery) async throws -> [SearchResult]
    func manifests() async throws -> [CodeSetManifest]
    func codeCount() async throws -> Int

    @discardableResult
    func ingest(_ codeSet: CodeSetImport) async throws -> IngestSummary

    @discardableResult
    func removeCodeSet(_ system: CodeSystem) async throws -> Int

    // MARK: - Hierarchy

    func detail(for code: ClinicalCode) async throws -> CodeDetail?
    func children(of parent: String?, in system: CodeSystem) async throws -> [ClinicalCode]
    func chapters(in system: CodeSystem) async throws -> [String]
    func roots(inChapter chapter: String, of system: CodeSystem) async throws -> [ClinicalCode]
}
