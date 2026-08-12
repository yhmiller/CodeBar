import CodeCore
import Observation

/// The clinician's own shorthand, as edited in Settings.
@MainActor
@Observable
public final class AbbreviationsViewModel {

    public private(set) var abbreviations: [Abbreviation] = []

    /// What the built-in table already covers, so the pane can say so rather than
    /// letting someone retype twenty entries CodeBar already knows.
    public let builtInCount = ClinicalAbbreviations.expansions.count

    private let library: (any CodeLibraryStoring)?

    /// Retained so tests can await a save rather than sleeping.
    @ObservationIgnored
    public private(set) var pendingWork: Task<Void, Never>?

    public init(library: (any CodeLibraryStoring)?) {
        self.library = library
    }

    public func load() async {
        abbreviations = (try? await library?.abbreviations()).flatMap { $0 } ?? []
    }

    /// Whether this pair could be stored, so the view can disable Add rather than
    /// accepting something that silently does nothing.
    public func canAdd(term: String, expansion: String) -> Bool {
        Abbreviation(term: term, expansion: expansion).isUsable
    }

    /// Adding an existing term replaces it, which is also how a built-in gets
    /// overridden.
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

    /// The built-in expansion this entry replaces, if it replaces one.
    ///
    /// Worth showing: someone redefining `RA` should see what they are
    /// overriding, since the two readings sit in different specialties and a
    /// silent override is how the wrong one gets used.
    public func overriddenBuiltIn(for abbreviation: Abbreviation) -> String? {
        ClinicalAbbreviations.expansions[abbreviation.term]
    }
}
