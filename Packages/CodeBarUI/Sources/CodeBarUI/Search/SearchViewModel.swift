import CodeCore
import Observation

/// How long typing must pause before a search is issued.
///
/// Long enough that a burst of keystrokes collapses into one query, short enough
/// that it reads as instant. Injectable so tests do not depend on wall-clock timing.
public let DEFAULT_SEARCH_DEBOUNCE = Duration.milliseconds(120)

/// How many recently-used codes the empty state offers. Enough to cover a
/// clinic session, few enough to stay scannable.
public let EMPTY_STATE_RECENT_LIMIT = 8

/// How many of the user's own codes influence ranking. Matches the store's own
/// cap; beyond this the query becomes mostly bind parameters.
public let PREFERRED_CODE_LIMIT = 50

/// Owns the search panel's state.
///
/// Two guarantees it exists to provide: a burst of keystrokes issues one query,
/// not one per character; and a slow query for "dia" can never land on top of a
/// faster one for "diabetes".
@MainActor
@Observable
public final class SearchViewModel {

    public private(set) var query: String = ""
    public private(set) var results: [SearchResult] = []
    public private(set) var selectedIndex: Int = 0

    /// Bumped each time the panel is about to be shown.
    ///
    /// Deliberately a bare counter rather than the model handing the view a
    /// string: the model must never drive the text field's contents. Doing that
    /// is what made the query walk backwards in phase 2. The view watches this
    /// and clears its own field.
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

    /// Tests await this to settle deterministically rather than sleeping.
    @ObservationIgnored
    var pendingSearch: Task<Void, Never>? { searchRunner.pending }

    /// Writes to the library are fire-and-forget from the view's point of view.
    /// Retained so tests can await them, exactly as `pendingSearch` is.
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

    /// Shown when the field is empty. Pins first, then recents.
    ///
    /// This is where the ranking gap gets addressed in practice: relevance
    /// ranking cannot know that E11.9 is the diabetes code someone reaches for
    /// every day, but their own history can.
    ///
    /// Cached here rather than read through on demand: the library is an actor,
    /// and a view cannot await.
    public private(set) var pinnedCodes: [ClinicalCode] = []
    public private(set) var recentCodes: [ClinicalCode] = []
    private var pinnedIDs: Set<String> = []

    /// Codes this person uses, ranked ahead of equally-relevant ones they have
    /// never touched. Pins count too: pinning is an explicit statement that a
    /// code matters, and waiting for usage to accumulate would ignore it.
    private var preferredIDs: Set<String> = []

    public var hasEmptyStateSuggestions: Bool {
        !pinnedCodes.isEmpty || !recentCodes.isEmpty
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

    /// Reloads the cached pins and recents.
    public func refreshLibrary() async {
        pinnedCodes = (try? await library.pinnedCodes()) ?? []
        recentCodes = (try? await library.recentCodes(limit: EMPTY_STATE_RECENT_LIMIT)) ?? []
        pinnedIDs = Set(pinnedCodes.map(\.id))

        let mostUsed = (try? await library.mostUsedCodes(limit: PREFERRED_CODE_LIMIT)) ?? []
        preferredIDs = pinnedIDs.union(mostUsed.map(\.id))
    }

    // MARK: - Querying

    public func setQuery(_ text: String) {
        query = text
        selectedIndex = 0

        // Read at search time rather than at init, so toggling a system in
        // Settings takes effect on the next keystroke without a restart.
        let query = SearchQuery(
            raw: text,
            systems: preferences.enabledSystems,
            preferredCodes: preferredIDs
        )

        searchRunner.run(query) { [weak self] found in
            self?.results = found
            self?.selectedIndex = 0
        }
    }

    /// Resets for a fresh appearance of the panel.
    ///
    /// The panel and its view are now built once and reused, so state does not
    /// clear itself by the view being thrown away.
    public func prepareForDisplay() {
        displaySessionID += 1
        setQuery("")
        pendingLibraryWork = Task { await refreshLibrary() }
    }

    // MARK: - Selection

    public func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = max(0, min(results.count - 1, selectedIndex + delta))
    }

    /// Identity of the highlighted result, for selection and scrolling.
    ///
    /// Exposed by identity rather than by index so the list can key its rows on
    /// something stable: keying a row on its position makes every row a new view
    /// whenever the result set changes, which leaves stale rows on screen.
    public var selectedResultID: SearchResult.ID? {
        results.indices.contains(selectedIndex) ? results[selectedIndex].id : nil
    }

    public func isSelected(_ result: SearchResult) -> Bool {
        result.id == selectedResultID
    }

    // MARK: - Copying

    /// Copies the highlighted result. Returns `false` when there is nothing to
    /// copy, so the caller knows whether to dismiss.
    @discardableResult
    public func copySelected(format: CopyFormat = .codeOnly) -> Bool {
        guard results.indices.contains(selectedIndex) else { return false }
        copy(results[selectedIndex].code, format: format)
        return true
    }

    public func copy(_ result: SearchResult, format: CopyFormat = .codeOnly) {
        copy(result.code, format: format)
    }

    public func copy(_ code: ClinicalCode, format: CopyFormat = .codeOnly) {
        pasteboard.write(format.string(for: code))
        pendingLibraryWork = Task {
            try? await library.recordUse(of: code, format: format)
            await refreshLibrary()
        }
    }
}
