import CodeCore
import Testing
@testable import CodeBarUI

@Suite("AbbreviationsViewModel")
@MainActor
struct AbbreviationsViewModelTests {

    private func model(_ library: FakeLibrary = FakeLibrary()) -> AbbreviationsViewModel {
        AbbreviationsViewModel(library: library)
    }

    @Test("should show what the user has already stored")
    func loadsStored() async {
        let library = FakeLibrary()
        await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin"))
        let model = model(library)

        await model.load()

        #expect(model.abbreviations.map(\.term) == ["pcn"])
    }

    @Test("should add an abbreviation the user typed")
    func addsOne() async {
        let model = model()

        model.add(term: "abx", expansion: "antibiotic")
        await model.pendingWork?.value

        #expect(model.abbreviations == [Abbreviation(term: "abx", expansion: "antibiotic")])
    }

    @Test("should remove an abbreviation")
    func removesOne() async {
        let model = model()
        model.add(term: "abx", expansion: "antibiotic")
        await model.pendingWork?.value

        model.remove(Abbreviation(term: "abx", expansion: "antibiotic"))
        await model.pendingWork?.value

        #expect(model.abbreviations.isEmpty)
    }

    @Test("should refuse a shortcut with nothing to expand it to")
    func refusesBlankExpansion() async {
        let model = model()

        model.add(term: "abx", expansion: "   ")
        await model.pendingWork?.value

        #expect(model.abbreviations.isEmpty)
    }

    @Test("should not offer to add an entry it would refuse")
    func cannotAddBlankExpansion() {
        #expect(model().canAdd(term: "abx", expansion: " ") == false)
    }

    @Test("should offer to add a complete entry")
    func canAddCompleteEntry() {
        #expect(model().canAdd(term: "abx", expansion: "antibiotic"))
    }

    /// A silent override is how the wrong reading of a letter pair gets used, so
    /// the pane names what an entry replaces.
    @Test("should report the built-in an entry overrides")
    func reportsOverriddenBuiltIn() {
        let overridden = model().overriddenBuiltIn(
            for: Abbreviation(term: "ra", expansion: "right atrium")
        )

        #expect(overridden == "rheumatoid arthritis")
    }

    @Test("should report nothing overridden for a term CodeBar does not know")
    func reportsNoOverrideForNewTerm() {
        let overridden = model().overriddenBuiltIn(
            for: Abbreviation(term: "pcn", expansion: "penicillin")
        )

        #expect(overridden == nil)
    }
}
