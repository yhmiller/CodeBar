import CodeCore
import Testing
@testable import CodeBarUI

@Suite("Copying and pinning")
@MainActor
struct CopyAndPinTests {

    private func makeModel(
        pasteboard: FakePasteboard = FakePasteboard(),
        usage: FakeUsageStore = FakeUsageStore()
    ) -> SearchViewModel {
        SearchViewModel(repository: CountingRepository(), pasteboard: pasteboard, usage: usage)
    }

    @Test("should copy just the code by default")
    func copiesCodeOnly() {
        let pasteboard = FakePasteboard()
        makeModel(pasteboard: pasteboard).copy(Samples.diabetes.code)

        #expect(pasteboard.written == ["E11.9"])
    }

    @Test("should copy the system, code and description in the long format")
    func copiesCodeWithDescription() {
        let pasteboard = FakePasteboard()
        makeModel(pasteboard: pasteboard).copy(Samples.diabetes.code, format: .codeAndDisplay)

        #expect(pasteboard.written ==
                ["ICD-10-CM E11.9 — Type 2 diabetes mellitus without complications"])
    }

    @Test("should remember a copied code as recent")
    func copyingRecordsRecent() {
        let usage = FakeUsageStore()
        makeModel(usage: usage).copy(Samples.diabetes.code)

        #expect(usage.recentCodes.first?.code == "E11.9")
    }

    @Test("should surface recents in the empty state")
    func recentsAppearInEmptyState() {
        let usage = FakeUsageStore()
        let model = makeModel(usage: usage)
        model.copy(Samples.diabetes.code)

        #expect(model.recentCodes.count == 1)
    }

    @Test("should pin a code through the view model")
    func pinsThroughViewModel() {
        let model = makeModel()
        model.togglePin(Samples.asthma.code)

        #expect(model.isPinned(Samples.asthma.code))
    }

    @Test("should surface pins in the empty state")
    func pinsAppearInEmptyState() {
        let model = makeModel()
        model.togglePin(Samples.asthma.code)

        #expect(model.pinnedCodes.map(\.code) == ["J45.909"])
    }

    @Test("should report having nothing to suggest before any use")
    func noSuggestionsInitially() {
        #expect(makeModel().hasEmptyStateSuggestions == false)
    }

    @Test("should report having suggestions once something is pinned")
    func suggestionsAfterPinning() {
        let model = makeModel()
        model.togglePin(Samples.asthma.code)

        #expect(model.hasEmptyStateSuggestions)
    }

    @Test("should advance the pin revision so the view refreshes")
    func pinningAdvancesRevision() {
        let model = makeModel()
        let before = model.pinRevision
        model.togglePin(Samples.asthma.code)

        #expect(model.pinRevision == before + 1)
    }
}
