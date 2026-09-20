import CodeCore
import Testing
@testable import CodeBarUI

@Suite("Window search")
@MainActor
struct WindowSearchTests {

    private func loaded(
        repository: some CodeRepository = TreeRepository(),
        preferences: FakePreferences = FakePreferences()
    ) async -> BrowseViewModel {
        let model = BrowseViewModel(repository: repository, library: FakeLibrary(),
                                    preferences: preferences, debounce: .milliseconds(10))
        await model.load()
        return model
    }

    @Test("should browse rather than search until something is typed")
    func browsesByDefault() async {
        #expect(await loaded().isSearching == false)
    }

    @Test("should switch to results once a query is typed")
    func switchesToSearch() async {
        let model = await loaded()

        model.search("diabetes")
        await model.pendingSearch?.value

        #expect(model.isSearching)
    }

    @Test("should return to browsing when the query is cleared")
    func returnsToBrowsing() async {
        let model = await loaded()
        model.search("diabetes")
        await model.pendingSearch?.value

        model.search("")
        await model.pendingSearch?.value

        #expect(model.isSearching == false)
    }

    @Test("should treat a whitespace-only query as no query")
    func whitespaceIsNotASearch() async {
        let model = await loaded()

        model.search("   ")
        await model.pendingSearch?.value

        #expect(model.isSearching == false)
    }

    @Test("should clear results when the query is cleared")
    func clearingEmptiesResults() async {
        let repository = SearchableTreeRepository()
        let model = await loaded(repository: repository)
        model.search("diabetes")
        await model.pendingSearch?.value

        model.search("")
        await model.pendingSearch?.value

        #expect(model.searchResults.isEmpty)
    }

    @Test("should search the whole code set, not the selected chapter")
    func searchesEverything() async {
        let repository = SearchableTreeRepository()
        let model = await loaded(repository: repository)
        model.selection = .chapter("Endocrine")
        await model.pendingWork?.value

        model.search("hypertension")
        await model.pendingSearch?.value

        #expect(model.searchResults.map(\.code.code) == ["I10"])
    }

    @Test("should honour the systems enabled in settings")
    func respectsSystemFilter() async {
        let repository = SearchableTreeRepository()
        let preferences = FakePreferences()
        preferences.setSystem(.loinc, enabled: false)
        let model = await loaded(repository: repository, preferences: preferences)

        model.search("diabetes")
        await model.pendingSearch?.value

        #expect(await repository.lastSystems?.contains(.loinc) == false)
    }

    @Test("should collapse a burst of keystrokes into one search")
    func debouncesTyping() async {
        let repository = SearchableTreeRepository()
        let model = BrowseViewModel(repository: repository, library: FakeLibrary(),
                                    preferences: FakePreferences(), debounce: .milliseconds(300))
        await model.load()

        for fragment in ["d", "di", "dia", "diab"] {
            model.search(fragment)
            try? await Task.sleep(for: .milliseconds(15))
        }
        await model.pendingSearch?.value

        #expect(await repository.searchCount == 1)
    }

    @Test("should select a code from the results")
    func selectsFromResults() async {
        let repository = SearchableTreeRepository()
        let model = await loaded(repository: repository)
        model.search("hypertension")
        await model.pendingSearch?.value

        model.selectedCode = model.searchResults.first?.code
        await model.pendingWork?.value

        #expect(model.detail?.code.code == "I10")
    }
}
