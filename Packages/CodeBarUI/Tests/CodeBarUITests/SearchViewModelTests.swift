import CodeCore
import Testing
@testable import CodeBarUI

/// Short enough to keep tests quick, long enough to be reached reliably.
private let TEST_DEBOUNCE = Duration.milliseconds(20)

/// Used by the debounce tests, which need keystrokes separated by real gaps —
/// otherwise the tasks never get a chance to run and the test would pass on
/// cancellation alone. The 20x margin over `TYPING_GAP` keeps it off a knife edge.
private let SLOW_DEBOUNCE = Duration.milliseconds(400)
private let TYPING_GAP = Duration.milliseconds(20)

@Suite("SearchViewModel")
@MainActor
struct SearchViewModelTests {

    private func makeModel(
        repository: (any CodeRepository)?,
        pasteboard: FakePasteboard = FakePasteboard(),
        usage: FakeUsageStore = FakeUsageStore(),
        preferences: FakePreferences = FakePreferences(),
        debounce: Duration = TEST_DEBOUNCE
    ) -> SearchViewModel {
        SearchViewModel(repository: repository, pasteboard: pasteboard,
                        usage: usage, preferences: preferences, debounce: debounce)
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

    @Test("should issue a single search for a burst of keystrokes")
    func burstIssuesOneSearch() async throws {
        let repository = CountingRepository(stubbed: [Samples.diabetes])
        let model = makeModel(repository: repository, debounce: SLOW_DEBOUNCE)

        try await type(["d", "di", "dia", "diab"], into: model)
        await model.pendingSearch?.value

        #expect(await repository.searchCount == 1)
    }

    @Test("should search for the final text of a burst, not an intermediate one")
    func burstSearchesFinalText() async throws {
        let repository = CountingRepository()
        let model = makeModel(repository: repository, debounce: SLOW_DEBOUNCE)

        try await type(["d", "di", "diab"], into: model)
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
