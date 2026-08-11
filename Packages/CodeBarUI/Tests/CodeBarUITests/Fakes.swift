import CodeCore
import Foundation

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
    private var stubbed: [SearchResult] = []

    init(stubbed: [SearchResult] = []) {
        self.stubbed = stubbed
    }

    func search(_ query: SearchQuery) async throws -> [SearchResult] {
        searchCount += 1
        receivedQueries.append(query.raw)
        return stubbed
    }

    func manifests() async throws -> [CodeSetManifest] { [] }
    func codeCount() async throws -> Int { 0 }
    @discardableResult func ingest(_ codeSet: CodeSetImport) async throws -> IngestSummary {
        IngestSummary(processed: 0, netAdded: 0, removed: 0, systems: [])
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
        IngestSummary(processed: 0, netAdded: 0, removed: 0, systems: [])
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
