import Foundation

/// A parsed, storage-agnostic search request.
///
/// All query interpretation happens here rather than in the store, so the
/// tokenizing and escaping rules are testable without a database.
public struct SearchQuery: Sendable, Equatable {
    public static let defaultLimit = 30

    /// Exactly what the user typed.
    public let raw: String
    /// Query folded for code-prefix matching, e.g. `e11.9` -> `E119`.
    public let normalizedCode: String
    /// FTS5 MATCH expression, or `nil` when the query has no searchable tokens.
    public let matchExpression: String?
    /// Systems to search. Empty means "no filter".
    public let systems: Set<CodeSystem>
    public let limit: Int

    /// `ClinicalCode.id` values the user reaches for often, ranked ahead of
    /// equally-relevant codes they have never used.
    ///
    /// Relevance and clinical frequency are different things: BM25 cannot know
    /// that E11.9 is the diabetes code a given clinician uses daily. This is the
    /// signal that does know, and it is the only one available that is not a
    /// guess about what "diabetes" ought to mean.
    public let preferredCodes: Set<String>

    public var isEmpty: Bool {
        normalizedCode.isEmpty && matchExpression == nil
    }

    public init(
        raw: String,
        systems: Set<CodeSystem> = [],
        limit: Int = SearchQuery.defaultLimit,
        preferredCodes: Set<String> = []
    ) {
        self.preferredCodes = preferredCodes
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        self.raw = trimmed
        self.normalizedCode = CodeNormalizer.normalize(trimmed)
        self.matchExpression = Self.matchExpression(for: trimmed)
        self.systems = systems
        self.limit = limit
    }

    /// Builds an FTS5 prefix-match expression from free text.
    ///
    /// Every token is double-quoted so that FTS5 operators a clinician might
    /// legitimately type — `-` in "non-hodgkin", `:` , `(`, `*` — are treated as
    /// text instead of syntax. Tokens with no alphanumeric content are dropped,
    /// since FTS5 rejects a quoted string that tokenizes to nothing.
    static func matchExpression(for text: String) -> String? {
        let tokens = text
            .split(whereSeparator: \.isWhitespace)
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
            .map { token -> String in
                let escaped = token.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\"*"
            }
        return tokens.isEmpty ? nil : tokens.joined(separator: " ")
    }
}
