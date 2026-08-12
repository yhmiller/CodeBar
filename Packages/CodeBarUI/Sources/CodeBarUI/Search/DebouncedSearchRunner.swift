import CodeCore

/// Runs a debounced, cancellable search.
///
/// Extracted rather than duplicated once the main window needed searching too.
/// The two cancellation points below are the difference between correct results
/// and a slow query for "dia" landing on top of a faster one for "diabetes", and
/// both are mutation-tested. Two copies of that would be two chances to quietly
/// lose it.
@MainActor
final class DebouncedSearchRunner {
    private let repository: (any CodeRepository)?
    private let debounce: Duration

    /// Retained so tests can await settling rather than sleeping.
    private(set) var pending: Task<Void, Never>?

    init(repository: (any CodeRepository)?, debounce: Duration) {
        self.repository = repository
        self.debounce = debounce
    }

    /// Cancels any search in flight and schedules this one.
    /// `onResults` runs only if this search is still the current one.
    func run(
        _ query: SearchQuery,
        onResults: @escaping @MainActor ([SearchResult]) -> Void
    ) {
        pending?.cancel()

        guard let repository, !query.isEmpty else {
            onResults([])
            pending = nil
            return
        }

        pending = Task { [debounce] in
            // Cancellation during the debounce is the common case — it is what
            // collapses a burst of keystrokes into a single query.
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }

            let found = (try? await repository.search(query)) ?? []

            // Re-checked after the await: a query already in flight when the
            // user kept typing must not overwrite the newer results.
            guard !Task.isCancelled else { return }
            onResults(found)
        }
    }
}
