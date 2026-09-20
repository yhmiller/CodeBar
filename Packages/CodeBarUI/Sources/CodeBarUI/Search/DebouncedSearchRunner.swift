import CodeCore

@MainActor
final class DebouncedSearchRunner {
    private let repository: (any CodeRepository)?
    private let debounce: Duration

    private(set) var pending: Task<Void, Never>?

    init(repository: (any CodeRepository)?, debounce: Duration) {
        self.repository = repository
        self.debounce = debounce
    }

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
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }

            let found = (try? await repository.search(query)) ?? []

            guard !Task.isCancelled else { return }
            onResults(found)
        }
    }
}
