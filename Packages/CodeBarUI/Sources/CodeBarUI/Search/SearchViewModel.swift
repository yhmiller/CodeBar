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
    private let debounce: Duration

    /// Retained so a new keystroke can cancel the previous search.
    /// Tests await it to settle deterministically rather than sleeping.
    @ObservationIgnored
    private(set) var pendingSearch: Task<Void, Never>?

    public init(
        repository: (any CodeRepository)?,
        pasteboard: any PasteboardWriting,
        debounce: Duration = DEFAULT_SEARCH_DEBOUNCE
    ) {
        self.repository = repository
        self.pasteboard = pasteboard
        self.debounce = debounce
    }

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

        pendingSearch = Task { [debounce] in
            // Cancellation during the debounce is the common case — it is what
            // collapses a burst of keystrokes into a single query.
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }

            let found = (try? await repository.search(SearchQuery(raw: text))) ?? []

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
    public func copySelected() -> Bool {
        guard results.indices.contains(selectedIndex) else { return false }
        copy(results[selectedIndex])
        return true
    }

    public func copy(_ result: SearchResult) {
        pasteboard.write(result.code.code)
    }
}
