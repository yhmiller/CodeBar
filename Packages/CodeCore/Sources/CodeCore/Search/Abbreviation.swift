import Foundation

public struct Abbreviation: Sendable, Equatable, Identifiable, Hashable {

    public var id: String { term }
    public let term: String
    public let expansion: String

    public init(term: String, expansion: String) {
        self.term = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.expansion = expansion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isUsable: Bool {
        !term.isEmpty && !expansion.isEmpty
    }
}

public extension Sequence<Abbreviation> {

    var expansionsByTerm: [String: String] {
        reduce(into: [:]) { result, abbreviation in
            guard abbreviation.isUsable else { return }
            result[abbreviation.term] = abbreviation.expansion
        }
    }
}
