import CodeCore
import Foundation

@MainActor
final class FakePreferences: PreferencesStoring {
    private var disabled: Set<CodeSystem> = []

    var enabledSystems: Set<CodeSystem> {
        Set(CodeSystem.allCases).subtracting(disabled)
    }

    func setSystem(_ system: CodeSystem, enabled: Bool) {
        if enabled { disabled.remove(system) } else { disabled.insert(system) }
    }

    var showsDockIcon = false
}

actor FakeLibrary: CodeLibraryStoring {
    private var pinned: [ClinicalCode] = []
    private var recent: [ClinicalCode] = []
    private var uses: [String: Int] = [:]

    func pinnedCodes() -> [ClinicalCode] { pinned }
    func isPinned(_ code: ClinicalCode) -> Bool { pinned.contains { $0.id == code.id } }

    @discardableResult
    func togglePin(_ code: ClinicalCode) -> Bool {
        if let index = pinned.firstIndex(where: { $0.id == code.id }) {
            pinned.remove(at: index)
            return false
        }
        pinned.insert(code, at: 0)
        return true
    }

    func recordUse(of code: ClinicalCode, format: CopyFormat) {
        uses[code.id, default: 0] += 1
        recent.removeAll { $0.id == code.id }
        recent.insert(code, at: 0)
    }

    func recentCodes(limit: Int) -> [ClinicalCode] {
        Array(recent.filter { code in !pinned.contains { $0.id == code.id } }.prefix(limit))
    }

    func mostUsedCodes(limit: Int) -> [ClinicalCode] {
        Array(recent.sorted { uses[$0.id, default: 0] > uses[$1.id, default: 0] }.prefix(limit))
    }

    func usageCount(for code: ClinicalCode) -> Int { uses[code.id, default: 0] }

    @discardableResult
    func adoptLegacyData(pinned: [ClinicalCode], recent: [ClinicalCode]) -> Bool { false }
}

@MainActor
final class FakePasteboard: PasteboardWriting {
    private(set) var written: [String] = []

    func write(_ string: String) {
        written.append(string)
    }
}

/// Returns canned results immediately and records how many searches it saw.
actor CountingRepository: CodeRepository {
    private(set) var searchCount = 0
    private(set) var receivedQueries: [String] = []
    private(set) var receivedSystems: [Set<CodeSystem>] = []
    private var stubbed: [SearchResult] = []

    init(stubbed: [SearchResult] = []) {
        self.stubbed = stubbed
    }

    func search(_ query: SearchQuery) async throws -> [SearchResult] {
        searchCount += 1
        receivedQueries.append(query.raw)
        receivedSystems.append(query.systems)
        return stubbed
    }

    func manifests() async throws -> [CodeSetManifest] { [] }
    func codeCount() async throws -> Int { 0 }
    @discardableResult func ingest(_ codeSet: CodeSetImport) async throws -> IngestSummary {
        IngestSummary(processed: 0, installedBefore: 0, installedAfter: 0, systems: [])
    }
    @discardableResult func removeCodeSet(_ system: CodeSystem) async throws -> Int { 0 }
}

/// A repository whose searches suspend until the test explicitly releases them.
///
/// Lets a test interleave a slow query with a fast one deterministically, rather
/// than racing two sleeps and hoping the ordering holds.
actor GatedRepository: CodeRepository {
    private var resultsByQuery: [String: [SearchResult]] = [:]
    private var startedQueries: Set<String> = []
    private var suspendedSearches: [String: CheckedContinuation<Void, Never>] = [:]
    private var startWaiters: [String: CheckedContinuation<Void, Never>] = [:]

    init(resultsByQuery: [String: [SearchResult]]) {
        self.resultsByQuery = resultsByQuery
    }

    func search(_ query: SearchQuery) async throws -> [SearchResult] {
        startedQueries.insert(query.raw)
        startWaiters.removeValue(forKey: query.raw)?.resume()

        await withCheckedContinuation { continuation in
            suspendedSearches[query.raw] = continuation
        }
        return resultsByQuery[query.raw] ?? []
    }

    /// Suspends until `raw` has entered `search`.
    func waitForSearchToStart(_ raw: String) async {
        guard !startedQueries.contains(raw) else { return }
        await withCheckedContinuation { continuation in
            startWaiters[raw] = continuation
        }
    }

    /// Lets a suspended search return.
    func release(_ raw: String) {
        suspendedSearches.removeValue(forKey: raw)?.resume()
    }

    func manifests() async throws -> [CodeSetManifest] { [] }
    func codeCount() async throws -> Int { 0 }
    @discardableResult func ingest(_ codeSet: CodeSetImport) async throws -> IngestSummary {
        IngestSummary(processed: 0, installedBefore: 0, installedAfter: 0, systems: [])
    }
    @discardableResult func removeCodeSet(_ system: CodeSystem) async throws -> Int { 0 }
}

enum Samples {
    static func result(_ code: String, _ display: String) -> SearchResult {
        SearchResult(
            code: ClinicalCode(code: code, display: display, system: .icd10cm),
            matchTier: .text
        )
    }

    static let diabetes = result("E11.9", "Type 2 diabetes mellitus without complications")
    static let hypertension = result("I10", "Essential (primary) hypertension")
    static let asthma = result("J45.909", "Unspecified asthma, uncomplicated")
}
