/// A code that matched a query, tagged with how it matched.
public struct SearchResult: Identifiable, Hashable, Sendable {
    /// Why a result is where it is in the list.
    ///
    /// Ranking is expressed as a discrete tier rather than a blended numeric
    /// score so that ordering is deterministic and assertable in tests: an exact
    /// code match always outranks a prefix match, which always outranks a
    /// full-text match, regardless of BM25 weighting.
    public enum MatchTier: Int, Sendable, Comparable, CaseIterable {
        case exactCode = 0
        case codePrefix = 1
        case text = 2

        public static func < (lhs: MatchTier, rhs: MatchTier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public var id: String { code.id }
    public let code: ClinicalCode
    public let matchTier: MatchTier

    public init(code: ClinicalCode, matchTier: MatchTier) {
        self.code = code
        self.matchTier = matchTier
    }
}
