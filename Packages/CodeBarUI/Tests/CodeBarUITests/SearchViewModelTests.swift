import CodeCore
import Testing
@testable import CodeBarUI

private let TEST_DEBOUNCE = Duration.milliseconds(20)
private let NEVER_ELAPSES = Duration.seconds(30)
private let TYPING_GAP = Duration.milliseconds(20)

@Suite("SearchViewModel")
@MainActor
struct SearchViewModelTests {

    private func makeModel(
        repository: (any CodeRepository)?,
        pasteboard: FakePasteboard = FakePasteboard(),
        library: FakeLibrary = FakeLibrary(),
        preferences: FakePreferences = FakePreferences(),
        debounce: Duration = TEST_DEBOUNCE
    ) -> SearchViewModel {
        SearchViewModel(repository: repository, pasteboard: pasteboard,
                        library: library, preferences: preferences, debounce: debounce)
    }

    private func type(_ fragments: [String], into model: SearchViewModel) async throws {
        for fragment in fragments {
            model.setQuery(fragment)
            try await Task.sleep(for: TYPING_GAP)
        }
    }

    // MARK: - Keyboard reach into the empty state

    @Test("should copy a pinned code with Return before anything is typed")
    func returnCopiesPinnedCodeWithoutTyping() async {
        let library = FakeLibrary()
        await library.togglePin(Samples.diabetes.code)
        let pasteboard = FakePasteboard()
        let model = makeModel(repository: CountingRepository(),
                              pasteboard: pasteboard, library: library)
        await model.refreshLibrary()

        #expect(model.copySelected())
        #expect(pasteboard.written == ["E11.9"])
    }

    @Test("should move the selection through pins and recents before anything is typed")
    func arrowsReachSuggestions() async {
        let library = FakeLibrary()
        await library.togglePin(Samples.diabetes.code)
        await library.togglePin(Samples.asthma.code)
        let model = makeModel(repository: CountingRepository(), library: library)
        await model.refreshLibrary()

        #expect(model.selectedCodeText == Samples.asthma.code.code)

        model.moveSelection(1)

        #expect(model.selectedCodeText == Samples.diabetes.code.code)
    }

    @Test("should pin the selected result")
    func pinsTheSelection() async throws {
        let library = FakeLibrary()
        let model = makeModel(repository: CountingRepository(stubbed: [Samples.diabetes]),
                              library: library)
        model.setQuery("diabetes")
        try await model.pendingSearch?.value

        #expect(model.togglePinOnSelection())
        await model.pendingLibraryWork?.value

        #expect(model.isPinned(Samples.diabetes.code))
    }

    @Test("should copy the nth result directly")
    func copiesByIndex() async throws {
        let pasteboard = FakePasteboard()
        let model = makeModel(
            repository: CountingRepository(stubbed: [Samples.diabetes, Samples.asthma]),
            pasteboard: pasteboard
        )
        model.setQuery("a")
        try await model.pendingSearch?.value

        #expect(model.copy(at: 1))
        #expect(pasteboard.written == [Samples.asthma.code.code])
    }

    @Test("should refuse an index beyond the visible rows")
    func refusesIndexBeyondResults() async throws {
        let model = makeModel(repository: CountingRepository(stubbed: [Samples.diabetes]))
        model.setQuery("diabetes")
        try await model.pendingSearch?.value

        #expect(model.copy(at: 4) == false)
    }

    // MARK: - Copy confirmation

    @Test("should record the long form when it copies with the description")
    func recordsLongFormCopy() async throws {
        let repository = CountingRepository(stubbed: [Samples.diabetes])
        let model = makeModel(repository: repository)
        model.setQuery("diabetes")
        try await model.pendingSearch?.value

        model.copySelected(format: .codeAndDisplay)

        #expect(model.lastCopiedText == "ICD-10-CM E11.9 — Type 2 diabetes mellitus without complications")
    }

    @Test("should record the bare code when it copies the code alone")
    func recordsCodeOnlyCopy() async throws {
        let repository = CountingRepository(stubbed: [Samples.diabetes])
        let model = makeModel(repository: repository)
        model.setQuery("diabetes")
        try await model.pendingSearch?.value

        model.copySelected(format: .codeOnly)

        #expect(model.lastCopiedText == "E11.9")
    }

    // MARK: - The system badge

    @Test("should hide the system badge when only one system is installed")
    func hidesBadgeForOneSystem() {
        let preferences = FakePreferences()
        for system in CodeSystem.allCases where system != .icd10cm {
            preferences.setSystem(system, enabled: false)
        }

        let model = makeModel(repository: nil, preferences: preferences)

        #expect(model.showsSystemBadge == false)
    }

    @Test("should show the system badge when more than one system is installed")
    func showsBadgeForSeveralSystems() {
        let preferences = FakePreferences()
        for system in CodeSystem.allCases where system != .icd10cm && system != .loinc {
            preferences.setSystem(system, enabled: false)
        }

        let model = makeModel(repository: nil, preferences: preferences)

        #expect(model.showsSystemBadge)
    }

    // MARK: - Debounce

    @Test("should not search while the user is still typing")
    func typingDefersTheSearch() async throws {
        let repository = CountingRepository()
        let model = makeModel(repository: repository, debounce: NEVER_ELAPSES)

        try await type(["d", "di", "dia", "diab"], into: model)

        #expect(await repository.searchCount == 0)
        model.pendingSearch?.cancel()
    }

    @Test("should search once, for the text the user stopped on")
    func settledBurstSearchesFinalText() async throws {
        let repository = CountingRepository()
        let model = makeModel(repository: repository)

        for fragment in ["d", "di", "dia", "diab"] {
            model.setQuery(fragment)
        }
        await model.pendingSearch?.value

        #expect(await repository.receivedQueries == ["diab"])
    }

    @Test("should publish the results of a settled search")
    func publishesSettledResults() async throws {
        let repository = CountingRepository(stubbed: [Samples.diabetes])
        let model = makeModel(repository: repository)

        model.setQuery("diabetes")
        await model.pendingSearch?.value

        #expect(model.results == [Samples.diabetes])
    }

    @Test("should not let a slow earlier query overwrite newer results")
    func staleResultsNeverOverwriteNewer() async throws {
        let repository = GatedRepository(resultsByQuery: [
            "dia": [Samples.hypertension],
            "diabetes": [Samples.diabetes]
        ])
        let model = makeModel(repository: repository)

        model.setQuery("dia")
        await repository.waitForSearchToStart("dia")
        let staleSearch = model.pendingSearch

        model.setQuery("diabetes")
        await repository.waitForSearchToStart("diabetes")

        await repository.release("diabetes")
        await model.pendingSearch?.value

        await repository.release("dia")
        await staleSearch?.value

        #expect(model.results == [Samples.diabetes])
    }

    // MARK: - Empty query

    @Test("should not reach the repository for an empty query")
    func emptyQuerySkipsTheRepository() async throws {
        let repository = CountingRepository()
        let model = makeModel(repository: repository)

        model.setQuery("")
        await model.pendingSearch?.value

        #expect(await repository.searchCount == 0)
    }

    @Test("should clear results when the query is cleared")
    func clearingQueryClearsResults() async throws {
        let repository = CountingRepository(stubbed: [Samples.diabetes])
        let model = makeModel(repository: repository)
        model.setQuery("diabetes")
        await model.pendingSearch?.value

        model.setQuery("")

        #expect(model.results.isEmpty)
    }

    @Test("should return no results when the database failed to open")
    func missingRepositoryYieldsNoResults() async throws {
        let model = makeModel(repository: nil)

        model.setQuery("diabetes")
        await model.pendingSearch?.value

        #expect(model.results.isEmpty)
    }

    // MARK: - Preparing to display

    @Test("should clear results when the panel is prepared for display")
    func prepareForDisplayClearsResults() async throws {
        let model = try await seededModel()

        model.prepareForDisplay()

        #expect(model.results.isEmpty)
    }

    @Test("should clear the query when the panel is prepared for display")
    func prepareForDisplayClearsQuery() async throws {
        let model = try await seededModel()

        model.prepareForDisplay()

        #expect(model.query.isEmpty)
    }

    @Test("should signal a new display session so the view can clear its field")
    func prepareForDisplayAdvancesSession() async throws {
        let model = try await seededModel()
        let before = model.displaySessionID

        model.prepareForDisplay()

        #expect(model.displaySessionID == before + 1)
    }

    @Test("should not let a search from a previous showing land after reopening")
    func prepareForDisplayCancelsPendingSearch() async throws {
        let repository = GatedRepository(resultsByQuery: ["diabetes": [Samples.diabetes]])
        let model = makeModel(repository: repository)

        model.setQuery("diabetes")
        await repository.waitForSearchToStart("diabetes")
        let staleSearch = model.pendingSearch

        model.prepareForDisplay()
        await repository.release("diabetes")
        await staleSearch?.value

        #expect(model.results.isEmpty)
    }

    // MARK: - Selection

    @Test("should move the selection down")
    func movesSelectionDown() async throws {
        let model = try await seededModel()

        model.moveSelection(1)

        #expect(model.selectedIndex == 1)
    }

    @Test("should clamp the selection at the last result")
    func clampsSelectionAtEnd() async throws {
        let model = try await seededModel()

        model.moveSelection(99)

        #expect(model.selectedIndex == 2)
    }

    @Test("should clamp the selection at the first result")
    func clampsSelectionAtStart() async throws {
        let model = try await seededModel()

        model.moveSelection(-99)

        #expect(model.selectedIndex == 0)
    }

    @Test("should ignore selection movement when there are no results")
    func ignoresSelectionWithoutResults() async throws {
        let model = makeModel(repository: CountingRepository())

        model.moveSelection(1)

        #expect(model.selectedIndex == 0)
    }

    @Test("should expose the highlighted result's identity")
    func exposesSelectedResultIdentity() async throws {
        let model = try await seededModel()

        model.moveSelection(1)

        #expect(model.selectedResultID == Samples.hypertension.id)
    }

    @Test("should have no selected identity when there are no results")
    func noSelectedIdentityWithoutResults() async throws {
        let model = makeModel(repository: CountingRepository())

        #expect(model.selectedResultID == nil)
    }

    @Test("should mark only the highlighted result as selected")
    func marksOnlyHighlightedResult() async throws {
        let model = try await seededModel()

        model.moveSelection(1)

        #expect(model.results.filter { model.isSelected($0) } == [Samples.hypertension])
    }

    @Test("should reset the selection when the query changes")
    func resetsSelectionOnNewQuery() async throws {
        let model = try await seededModel()
        model.moveSelection(2)

        model.setQuery("asthma")

        #expect(model.selectedIndex == 0)
    }

    // MARK: - Copying

    @Test("should copy the highlighted code to the pasteboard")
    func copiesHighlightedCode() async throws {
        let pasteboard = FakePasteboard()
        let model = try await seededModel(pasteboard: pasteboard)
        model.moveSelection(1)

        model.copySelected()

        #expect(pasteboard.written == [Samples.hypertension.code.code])
    }

    @Test("should report success when a code was copied")
    func reportsSuccessfulCopy() async throws {
        let model = try await seededModel()

        #expect(model.copySelected())
    }

    @Test("should report failure when there is nothing to copy")
    func reportsNothingToCopy() async throws {
        let model = makeModel(repository: CountingRepository())

        #expect(model.copySelected() == false)
    }

    @Test("should write nothing to the pasteboard when there is nothing to copy")
    func writesNothingWhenEmpty() async throws {
        let pasteboard = FakePasteboard()
        let model = makeModel(repository: CountingRepository(), pasteboard: pasteboard)

        model.copySelected()

        #expect(pasteboard.written.isEmpty)
    }

    @Test("should copy a code chosen directly rather than the highlighted one")
    func copiesDirectlyChosenCode() async throws {
        let pasteboard = FakePasteboard()
        let model = try await seededModel(pasteboard: pasteboard)

        model.copy(Samples.asthma)

        #expect(pasteboard.written == [Samples.asthma.code.code])
    }

    // MARK: - Helpers

    private func seededModel(pasteboard: FakePasteboard = FakePasteboard()) async throws -> SearchViewModel {
        let repository = CountingRepository(
            stubbed: [Samples.diabetes, Samples.hypertension, Samples.asthma]
        )
        let model = makeModel(repository: repository, pasteboard: pasteboard)
        model.setQuery("diabetes")
        await model.pendingSearch?.value
        return model
    }
}

@Suite("Own abbreviations reaching search")
@MainActor
struct SearchAbbreviationTests {

    private func makeModel(
        repository: CountingRepository,
        library: FakeLibrary
    ) -> SearchViewModel {
        SearchViewModel(repository: repository, pasteboard: FakePasteboard(),
                        library: library, preferences: FakePreferences(),
                        debounce: TEST_DEBOUNCE)
    }

    @Test("should expand a term the user stored in their library")
    func expandsAStoredTerm() async throws {
        let repository = CountingRepository()
        let library = FakeLibrary()
        await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin"))
        let model = makeModel(repository: repository, library: library)
        await model.refreshLibrary()

        model.setQuery("pcn")
        await model.pendingSearch?.value

        let expression = await repository.receivedExpressions.last ?? nil
        #expect(expression?.contains(#""penicillin"*"#) == true)
    }

    @Test("should not expand a term before the library has been read")
    func doesNotExpandBeforeRefresh() async throws {
        let repository = CountingRepository()
        let library = FakeLibrary()
        await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin"))
        let model = makeModel(repository: repository, library: library)

        model.setQuery("pcn")
        await model.pendingSearch?.value

        let expression = await repository.receivedExpressions.last ?? nil
        #expect(expression?.contains("penicillin") == false)
    }
}
