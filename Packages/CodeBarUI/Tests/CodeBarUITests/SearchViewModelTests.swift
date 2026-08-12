import CodeCore
import Testing
@testable import CodeBarUI

/// Short enough to keep tests quick, long enough to be reached reliably.
private let TEST_DEBOUNCE = Duration.milliseconds(20)

/// Long enough that no scheduling delay can reach it, so "nothing searched yet"
/// means the debounce deferred the work rather than the machine being quick.
///
/// It never elapses in a test — the pending task is cancelled instead — so its
/// length costs nothing. An earlier 400ms value was reached by a 20ms typing gap
/// overshooting under parallel test load, which failed the suite spuriously.
private let NEVER_ELAPSES = Duration.seconds(30)

/// Real gaps, so an absent debounce would let intermediate searches through.
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

    /// Types each fragment with a real pause between them, so an absent debounce
    /// would let the intermediate searches actually reach the repository.
    private func type(_ fragments: [String], into model: SearchViewModel) async throws {
        for fragment in fragments {
            model.setQuery(fragment)
            try await Task.sleep(for: TYPING_GAP)
        }
    }

    // MARK: - Debounce

    /// Covers the deferral itself: keystrokes arrive with real gaps between them,
    /// and none of them reaches the repository while typing continues.
    ///
    /// Without a debounce every fragment would search immediately, since the gaps
    /// give each task room to run. Asserting on zero rather than on a settled
    /// count is what keeps this off a timing threshold — there is no duration a
    /// slow machine could overshoot into.
    @Test("should not search while the user is still typing")
    func typingDefersTheSearch() async throws {
        let repository = CountingRepository()
        let model = makeModel(repository: repository, debounce: NEVER_ELAPSES)

        try await type(["d", "di", "dia", "diab"], into: model)

        #expect(await repository.searchCount == 0)
        model.pendingSearch?.cancel()
    }

    /// Covers the other half: once typing stops, exactly one search runs and it
    /// carries the final text.
    ///
    /// The fragments are deliberately not spaced here. Cancellation alone would
    /// collapse them, which is precisely why this cannot stand in for the
    /// deferral test above — it is the pair that pins the behaviour down.
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

        // Let "dia" get past the debounce and into the repository, so this
        // exercises the post-await cancellation check rather than the debounce.
        model.setQuery("dia")
        await repository.waitForSearchToStart("dia")
        let staleSearch = model.pendingSearch

        model.setQuery("diabetes")
        await repository.waitForSearchToStart("diabetes")

        // Order matters: the newer query must land first, so that releasing the
        // stale one afterwards is a genuine attempt to overwrite it. Releasing
        // the stale query first would let it be overwritten either way, and the
        // test would pass even without the cancellation check.
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

/// The path from the stored abbreviation to the query the store receives.
///
/// The pieces either side of this are covered elsewhere — CodeCore expands the
/// expression, CodeLibrary stores the entry — so what is left to prove is that
/// the view model carries one to the other.
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

    /// Guards the refresh, not just the plumbing: without reloading, a term added
    /// in Settings would not reach search until the app restarted.
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
