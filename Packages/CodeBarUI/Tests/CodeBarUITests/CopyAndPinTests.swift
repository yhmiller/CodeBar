import CodeCore
import Testing
@testable import CodeBarUI

@Suite("Copying and pinning")
@MainActor
struct CopyAndPinTests {

    private func makeModel(
        pasteboard: FakePasteboard = FakePasteboard(),
        library: FakeLibrary = FakeLibrary(),
        preferences: FakePreferences = FakePreferences()
    ) -> SearchViewModel {
        SearchViewModel(repository: CountingRepository(), pasteboard: pasteboard,
                        library: library, preferences: preferences,
                        debounce: .milliseconds(10))
    }

    /// Library writes run in a detached task; awaiting the handle keeps these
    /// deterministic rather than racing them.
    private func settle(_ model: SearchViewModel) async {
        await model.pendingLibraryWork?.value
    }

    // MARK: - Copy formats

    @Test("should copy just the code by default")
    func copiesCodeOnly() async {
        let pasteboard = FakePasteboard()
        let model = makeModel(pasteboard: pasteboard)

        model.copy(Samples.diabetes.code)
        await settle(model)

        #expect(pasteboard.written == ["E11.9"])
    }

    @Test("should copy the system, code and description in the long format")
    func copiesCodeWithDescription() async {
        let pasteboard = FakePasteboard()
        let model = makeModel(pasteboard: pasteboard)

        model.copy(Samples.diabetes.code, format: .codeAndDisplay)
        await settle(model)

        #expect(pasteboard.written ==
                ["ICD-10-CM E11.9 — Type 2 diabetes mellitus without complications"])
    }

    // MARK: - Library

    @Test("should record a copied code in the library")
    func copyingRecordsUse() async {
        let library = FakeLibrary()
        let model = makeModel(library: library)

        model.copy(Samples.diabetes.code)
        await settle(model)

        #expect(await library.usageCount(for: Samples.diabetes.code) == 1)
    }

    @Test("should surface a copied code as recent")
    func recentsAppearInEmptyState() async {
        let model = makeModel()

        model.copy(Samples.diabetes.code)
        await settle(model)

        #expect(model.recentCodes.map(\.code) == ["E11.9"])
    }

    @Test("should pin a code through the view model")
    func pinsThroughViewModel() async {
        let model = makeModel()

        model.togglePin(Samples.asthma.code)
        await settle(model)

        #expect(model.isPinned(Samples.asthma.code))
    }

    @Test("should surface pins in the empty state")
    func pinsAppearInEmptyState() async {
        let model = makeModel()

        model.togglePin(Samples.asthma.code)
        await settle(model)

        #expect(model.pinnedCodes.map(\.code) == ["J45.909"])
    }

    @Test("should unpin a code that was already pinned")
    func unpinsThroughViewModel() async {
        let model = makeModel()
        model.togglePin(Samples.asthma.code)
        await settle(model)

        model.togglePin(Samples.asthma.code)
        await settle(model)

        #expect(model.pinnedCodes.isEmpty)
    }

    @Test("should stop listing a code as recent once it is pinned")
    func pinnedCodesLeaveRecents() async {
        let model = makeModel()
        model.copy(Samples.diabetes.code)
        await settle(model)

        model.togglePin(Samples.diabetes.code)
        await settle(model)

        #expect(model.recentCodes.isEmpty)
    }

    @Test("should report having nothing to suggest before any use")
    func noSuggestionsInitially() {
        #expect(makeModel().hasEmptyStateSuggestions == false)
    }

    @Test("should report having suggestions once something is pinned")
    func suggestionsAfterPinning() async {
        let model = makeModel()

        model.togglePin(Samples.asthma.code)
        await settle(model)

        #expect(model.hasEmptyStateSuggestions)
    }

    @Test("should load the library when the panel is prepared for display")
    func prepareForDisplayLoadsLibrary() async {
        let library = FakeLibrary()
        await library.togglePin(Samples.asthma.code)
        let model = makeModel(library: library)

        model.prepareForDisplay()
        await settle(model)

        #expect(model.pinnedCodes.map(\.code) == ["J45.909"])
    }

    // MARK: - Per-system search filtering

    @Test("should search every system when none are disabled")
    func searchesAllSystemsByDefault() async throws {
        let repository = CountingRepository()
        let model = SearchViewModel(repository: repository, pasteboard: FakePasteboard(),
                                    library: FakeLibrary(), preferences: FakePreferences(),
                                    debounce: .milliseconds(10))

        model.setQuery("diabetes")
        await model.pendingSearch?.value

        #expect(await repository.receivedSystems.first == Set(CodeSystem.allCases))
    }

    @Test("should exclude a system the user turned off in settings")
    func excludesDisabledSystem() async throws {
        let repository = CountingRepository()
        let preferences = FakePreferences()
        preferences.setSystem(.loinc, enabled: false)
        let model = SearchViewModel(repository: repository, pasteboard: FakePasteboard(),
                                    library: FakeLibrary(), preferences: preferences,
                                    debounce: .milliseconds(10))

        model.setQuery("creatinine")
        await model.pendingSearch?.value

        #expect(await repository.receivedSystems.first?.contains(.loinc) == false)
    }

    @Test("should pick up a settings change without needing a restart")
    func picksUpPreferenceChangeImmediately() async throws {
        let repository = CountingRepository()
        let preferences = FakePreferences()
        let model = SearchViewModel(repository: repository, pasteboard: FakePasteboard(),
                                    library: FakeLibrary(), preferences: preferences,
                                    debounce: .milliseconds(10))
        model.setQuery("first")
        await model.pendingSearch?.value

        preferences.setSystem(.cpt, enabled: false)
        model.setQuery("second")
        await model.pendingSearch?.value

        #expect(await repository.receivedSystems.last?.contains(.cpt) == false)
    }
}
