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

    private(set) var lastPreferred: Set<String> = []

    func usageCount(for code: ClinicalCode) -> Int { uses[code.id, default: 0] }

    @discardableResult
    func adoptLegacyData(pinned: [ClinicalCode], recent: [ClinicalCode]) -> Bool { false }

    private var storedLists: [CodeList] = []
    private var members: [Int: [ClinicalCode]] = [:]
    private var storedNotes: [String: String] = [:]

    func lists() -> [CodeList] { storedLists }

    @discardableResult
    func createList(named name: String, detail: String?) -> CodeList {
        let list = CodeList(id: storedLists.count + 1, name: name, detail: detail,
                            createdAt: Date(), count: 0)
        storedLists.append(list)
        return list
    }

    func renameList(_ id: Int, to name: String) {}
    func deleteList(_ id: Int) { storedLists.removeAll { $0.id == id } }
    func codes(inList id: Int) -> [ClinicalCode] { members[id] ?? [] }
    func addCode(_ code: ClinicalCode, toList id: Int) { members[id, default: []].append(code) }
    func removeCode(_ code: ClinicalCode, fromList id: Int) {
        members[id]?.removeAll { $0.id == code.id }
    }

    var storedAbbreviations: [Abbreviation] = []

    func abbreviations() -> [Abbreviation] { storedAbbreviations.sorted { $0.term < $1.term } }

    func saveAbbreviation(_ abbreviation: Abbreviation) {
        storedAbbreviations.removeAll { $0.term == abbreviation.term }
        storedAbbreviations.append(abbreviation)
    }

    func removeAbbreviation(term: String) {
        storedAbbreviations.removeAll { $0.term == term.lowercased() }
    }

    func note(for code: ClinicalCode) -> String? { storedNotes[code.id] }
    func setNote(_ body: String, for code: ClinicalCode) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        storedNotes[code.id] = trimmed.isEmpty ? nil : trimmed
    }
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
    private(set) var receivedPreferred: [Set<String>] = []
    /// The FTS expression, which is where abbreviation expansion ends up.
    private(set) var receivedExpressions: [String?] = []
    private var stubbed: [SearchResult] = []

    init(stubbed: [SearchResult] = []) {
        self.stubbed = stubbed
    }

    func search(_ query: SearchQuery) async throws -> [SearchResult] {
        searchCount += 1
        receivedQueries.append(query.raw)
        receivedSystems.append(query.systems)
        receivedPreferred.append(query.preferredCodes)
        receivedExpressions.append(query.matchExpression)
        return stubbed
    }

    func manifests() async throws -> [CodeSetManifest] { [] }
    func codeCount() async throws -> Int { 0 }
    @discardableResult func ingest(_ codeSet: CodeSetImport) async throws -> IngestSummary {
        IngestSummary(processed: 0, installedBefore: 0, installedAfter: 0, systems: [])
    }
    @discardableResult func removeCodeSet(_ system: CodeSystem) async throws -> Int { 0 }
    func detail(for code: ClinicalCode) async throws -> CodeDetail? { nil }
    func children(of parent: String?, in system: CodeSystem) async throws -> [ClinicalCode] { [] }
    func chapters(in system: CodeSystem) async throws -> [String] { [] }
    func roots(inChapter chapter: String, of system: CodeSystem) async throws -> [ClinicalCode] { [] }
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
    func detail(for code: ClinicalCode) async throws -> CodeDetail? { nil }
    func children(of parent: String?, in system: CodeSystem) async throws -> [ClinicalCode] { [] }
    func chapters(in system: CodeSystem) async throws -> [String] { [] }
    func roots(inChapter chapter: String, of system: CodeSystem) async throws -> [ClinicalCode] { [] }
}

enum Samples {
    static func result(_ code: String, _ display: String) -> SearchResult {
        SearchResult(
            code: ClinicalCode(code: code, display: display, system: .icd10cm, isBillable: true),
            matchTier: .text
        )
    }

    static let diabetes = result("E11.9", "Type 2 diabetes mellitus without complications")
    static let hypertension = result("I10", "Essential (primary) hypertension")
    static let asthma = result("J45.909", "Unspecified asthma, uncomplicated")

    /// A category header — the badge case worth keeping an eye on.
    static let header = SearchResult(
        code: ClinicalCode(code: "E11", display: "Type 2 diabetes mellitus",
                           system: .icd10cm, isBillable: false),
        matchTier: .exactCode
    )

    /// The honest worst case: a real CMS description at 88 characters.
    ///
    /// Every clause after the comma changes which claim is correct — *which*
    /// femur, *which* encounter, open or closed. A row that truncates here is a
    /// row that hides the answer the user came for.
    static let longDescription = result(
        "S72.001A",
        "Fracture of unspecified part of neck of right femur, "
            + "initial encounter for closed fracture"
    )
}
