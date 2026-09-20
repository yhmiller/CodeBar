import CodeCore
import Observation

@MainActor
@Observable
public final class AbbreviationsViewModel {

    public private(set) var abbreviations: [Abbreviation] = []
    public let builtInCount = ClinicalAbbreviations.expansions.count

    private let library: (any CodeLibraryStoring)?

    @ObservationIgnored
    public private(set) var pendingWork: Task<Void, Never>?

    public init(library: (any CodeLibraryStoring)?) {
        self.library = library
    }

    public func load() async {
        abbreviations = (try? await library?.abbreviations()).flatMap { $0 } ?? []
    }

    public func canAdd(term: String, expansion: String) -> Bool {
        Abbreviation(term: term, expansion: expansion).isUsable
    }

    public func add(term: String, expansion: String) {
        let abbreviation = Abbreviation(term: term, expansion: expansion)
        guard abbreviation.isUsable else { return }

        pendingWork = Task {
            try? await library?.saveAbbreviation(abbreviation)
            await load()
        }
    }

    public func remove(_ abbreviation: Abbreviation) {
        pendingWork = Task {
            try? await library?.removeAbbreviation(term: abbreviation.term)
            await load()
        }
    }

    public func overriddenBuiltIn(for abbreviation: Abbreviation) -> String? {
        ClinicalAbbreviations.expansions[abbreviation.term]
    }
}
