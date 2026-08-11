import CodeCore
import Observation

/// How long typing must pause before a search is issued.
///
/// Long enough that a burst of keystrokes collapses into one query, short enough
/// that it reads as instant. Injectable so tests do not depend on wall-clock timing.
public let DEFAULT_SEARCH_DEBOUNCE = Duration.milliseconds(120)

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
    private let usage: any CodeUsageTracking
    private let preferences: any PreferencesStoring
    private let debounce: Duration

    /// Retained so a new keystroke can cancel the previous search.
    /// Tests await it to settle deterministically rather than sleeping.
    @ObservationIgnored
    private(set) var pendingSearch: Task<Void, Never>?

    public init(
        repository: (any CodeRepository)?,
        pasteboard: any PasteboardWriting,
        usage: any CodeUsageTracking,
        preferences: any PreferencesStoring,
        debounce: Duration = DEFAULT_SEARCH_DEBOUNCE
    ) {
        self.repository = repository
        self.pasteboard = pasteboard
        self.usage = usage
        self.preferences = preferences
        self.debounce = debounce
    }

    // MARK: - Pinned and recent

    /// Shown when the field is empty. Pins first, then recents.
    ///
    /// This is where the ranking gap gets addressed in practice: BM25 cannot know
    /// that E11.9 is the diabetes code someone reaches for every day, but their
    /// own pins can.
    public var pinnedCodes: [ClinicalCode] { usage.pinnedCodes }
    public var recentCodes: [ClinicalCode] { usage.recentCodes }

    public var hasEmptyStateSuggestions: Bool {
        !pinnedCodes.isEmpty || !recentCodes.isEmpty
    }

    public func isPinned(_ code: ClinicalCode) -> Bool {
        usage.isPinned(code)
    }

    public func togglePin(_ code: ClinicalCode) {
        usage.togglePin(code)
        pinRevision += 1
    }

    /// Bumped so SwiftUI re-reads the pin lists, which live in the usage store
    /// rather than in observed properties of this model.
    public private(set) var pinRevision = 0

    // MARK: - Querying

    public func setQuery(_ text: String) {
        query = text
        selectedIndex = 0
        pendingSearch?.cancel()

        guard let repository, !text.isEmpty else {
            results = []
            pendingSearch = nil
            return
        }

        // Read at search time rather than at init, so toggling a system in
        // Settings takes effect on the next keystroke without a restart.
        let systems = preferences.enabledSystems

        pendingSearch = Task { [debounce] in
            // Cancellation during the debounce is the common case — it is what
            // collapses a burst of keystrokes into a single query.
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }

            let found = (try? await repository.search(
                SearchQuery(raw: text, systems: systems)
            )) ?? []

            // Re-checked after the await: a query already in flight when the
            // user kept typing must not overwrite the newer results.
            guard !Task.isCancelled else { return }
            results = found
            selectedIndex = 0
        }
    }

    /// Resets for a fresh appearance of the panel.
    ///
    /// The panel and its view are now built once and reused, so state does not
    /// clear itself by the view being thrown away.
    public func prepareForDisplay() {
        displaySessionID += 1
        setQuery("")
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
        usage.recordUse(of: code)
        pinRevision += 1
    }
}
