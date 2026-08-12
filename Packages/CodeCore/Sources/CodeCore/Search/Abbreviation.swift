import Foundation

/// A clinician's own shorthand, expanded into the words a description uses.
///
/// The built-in table in `ClinicalAbbreviations` deliberately stops at
/// expansions nobody argues about. Everything past that point is local: a
/// department's own contractions, a specialty's reading of a letter pair, the
/// shorthand a particular clinic writes on its own forms. Guessing at those
/// would put words in a clinician's mouth; letting them say it costs nothing.
///
/// Like the built-ins this expands the *query*, never the code. `pcn` searching
/// as "penicillin" is a fact about vocabulary. Pointing `pcn` at a particular
/// code would be a clinical judgement made on the user's behalf, and a wrong one
/// reaches a claim.
public struct Abbreviation: Sendable, Equatable, Identifiable, Hashable {

    public var id: String { term }

    /// Always lowercase and trimmed, because lookup is case-insensitive and the
    /// user typed it into a text field.
    public let term: String

    /// The phrase to search for instead. Tokenized like any other query text.
    public let expansion: String

    public init(term: String, expansion: String) {
        self.term = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.expansion = expansion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Both halves must say something. A blank term would match every query and
    /// a blank expansion would search for nothing.
    public var isUsable: Bool {
        !term.isEmpty && !expansion.isEmpty
    }
}

public extension Sequence<Abbreviation> {

    /// Collapsed into the form `SearchQuery` expands with.
    var expansionsByTerm: [String: String] {
        reduce(into: [:]) { result, abbreviation in
            guard abbreviation.isUsable else { return }
            result[abbreviation.term] = abbreviation.expansion
        }
    }
}
