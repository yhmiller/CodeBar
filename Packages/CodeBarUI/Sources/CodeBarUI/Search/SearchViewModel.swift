import CodeCore
import Observation

public let DEFAULT_SEARCH_DEBOUNCE = Duration.milliseconds(120)
public let EMPTY_STATE_RECENT_LIMIT = 8
public let PREFERRED_CODE_LIMIT = 50

@MainActor
@Observable
public final class SearchViewModel {

    public private(set) var query: String = ""
    public private(set) var results: [SearchResult] = []
    public private(set) var selectedIndex: Int = 0

    public private(set) var displaySessionID = 0

    private let repository: (any CodeRepository)?
    private let pasteboard: any PasteboardWriting
    private let library: any CodeLibraryStoring
    private let preferences: any PreferencesStoring
    private let debounce: Duration

    @ObservationIgnored
    private lazy var searchRunner = DebouncedSearchRunner(
        repository: repository, debounce: debounce
    )

    @ObservationIgnored
    var pendingSearch: Task<Void, Never>? { searchRunner.pending }

    @ObservationIgnored
    public private(set) var pendingLibraryWork: Task<Void, Never>?

    public init(
        repository: (any CodeRepository)?,
        pasteboard: any PasteboardWriting,
        library: any CodeLibraryStoring,
        preferences: any PreferencesStoring,
        debounce: Duration = DEFAULT_SEARCH_DEBOUNCE
    ) {
        self.repository = repository
        self.pasteboard = pasteboard
        self.library = library
        self.preferences = preferences
        self.debounce = debounce
    }

    // MARK: - Pinned and recent

    public private(set) var pinnedCodes: [ClinicalCode] = []
    public private(set) var recentCodes: [ClinicalCode] = []
    private var pinnedIDs: Set<String> = []
    private var preferredIDs: Set<String> = []
    private var ownAbbreviations: [String: String] = [:]

    public var hasEmptyStateSuggestions: Bool {
        !pinnedCodes.isEmpty || !recentCodes.isEmpty
    }

    public var showsSystemBadge: Bool {
        preferences.enabledSystems.count > 1
    }

    public func isPinned(_ code: ClinicalCode) -> Bool {
        pinnedIDs.contains(code.id)
    }

    public func togglePin(_ code: ClinicalCode) {
        pendingLibraryWork = Task {
            try? await library.togglePin(code)
            await refreshLibrary()
        }
    }

    public func refreshLibrary() async {
        pinnedCodes = (try? await library.pinnedCodes()) ?? []
        recentCodes = (try? await library.recentCodes(limit: EMPTY_STATE_RECENT_LIMIT)) ?? []
        pinnedIDs = Set(pinnedCodes.map(\.id))

        let mostUsed = (try? await library.mostUsedCodes(limit: PREFERRED_CODE_LIMIT)) ?? []
        preferredIDs = pinnedIDs.union(mostUsed.map(\.id))

        ownAbbreviations = ((try? await library.abbreviations()) ?? []).expansionsByTerm
    }

    // MARK: - Querying

    public func setQuery(_ text: String) {
        query = text
        selectedIndex = 0

        let query = SearchQuery(
            raw: text,
            systems: preferences.enabledSystems,
            preferredCodes: preferredIDs,
            abbreviations: ownAbbreviations
        )

        searchRunner.run(query) { [weak self] found in
            self?.results = found
            self?.selectedIndex = 0
        }
    }

    public func prepareForDisplay() {
        displaySessionID += 1
        setQuery("")
        pendingLibraryWork = Task { await refreshLibrary() }
    }

    // MARK: - Selection

    public var selectableCodes: [ClinicalCode] {
        query.isEmpty ? pinnedCodes + recentCodes : results.map(\.code)
    }

    public func moveSelection(_ delta: Int) {
        let codes = selectableCodes
        guard !codes.isEmpty else { return }
        selectedIndex = max(0, min(codes.count - 1, selectedIndex + delta))
    }

    public func isSelected(_ code: ClinicalCode) -> Bool {
        let codes = selectableCodes
        guard codes.indices.contains(selectedIndex) else { return false }
        return codes[selectedIndex].id == code.id
    }

    @discardableResult
    public func togglePinOnSelection() -> Bool {
        let codes = selectableCodes
        guard codes.indices.contains(selectedIndex) else { return false }
        togglePin(codes[selectedIndex])
        return true
    }

    public var selectedCodeText: String? {
        selectedCode?.code
    }

    public var selectedCode: ClinicalCode? {
        let codes = selectableCodes
        guard codes.indices.contains(selectedIndex) else { return nil }
        return codes[selectedIndex]
    }

    @discardableResult
    public func copy(at index: Int, format: CopyFormat = .codeOnly) -> Bool {
        let codes = selectableCodes
        guard codes.indices.contains(index) else { return false }
        copy(codes[index], format: format)
        return true
    }

    public var selectedResultID: SearchResult.ID? {
        results.indices.contains(selectedIndex) ? results[selectedIndex].id : nil
    }

    public func isSelected(_ result: SearchResult) -> Bool {
        result.id == selectedResultID
    }

    // MARK: - Copying

    @discardableResult
    public func copySelected(format: CopyFormat = .codeOnly) -> Bool {
        copy(at: selectedIndex, format: format)
    }

    public func copy(_ result: SearchResult, format: CopyFormat = .codeOnly) {
        copy(result.code, format: format)
    }

    public private(set) var lastCopiedText: String?

    public func copy(_ code: ClinicalCode, format: CopyFormat = .codeOnly) {
        let written = format.string(for: code)
        pasteboard.write(written)
        lastCopiedText = written
        pendingLibraryWork = Task {
            try? await library.recordUse(of: code, format: format)
            await refreshLibrary()
        }
    }
}
