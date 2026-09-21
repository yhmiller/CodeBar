import Foundation

public struct SearchQuery: Sendable, Equatable {
    public static let defaultLimit = 30

    public let raw: String
    public let text: String
    public let scopedSystem: CodeSystem?
    public let scopeTag: String?
    public let normalizedCode: String
    public let matchExpression: String?
    public let systems: Set<CodeSystem>
    public let limit: Int
    public let preferredCodes: Set<String>

    public var isEmpty: Bool {
        normalizedCode.isEmpty && matchExpression == nil
    }

    public init(
        raw: String,
        systems: Set<CodeSystem> = [],
        scopedSystem: CodeSystem? = nil,
        limit: Int = SearchQuery.defaultLimit,
        preferredCodes: Set<String> = [],
        abbreviations: [String: String] = [:]
    ) {
        self.preferredCodes = preferredCodes
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        self.raw = trimmed
        let parsed = QueryScoper.parse(trimmed)
        let effectiveScope = scopedSystem ?? parsed.scopedSystem
        self.scopedSystem = effectiveScope
        self.scopeTag = parsed.tag
        self.text = parsed.cleanText
        self.normalizedCode = CodeNormalizer.normalize(parsed.cleanText)
        self.matchExpression = Self.matchExpression(for: parsed.cleanText, abbreviations: abbreviations)
        if let effectiveScope {
            self.systems = [effectiveScope]
        } else {
            self.systems = systems
        }
        self.limit = limit
    }

    static func matchExpression(
        for text: String,
        abbreviations: [String: String] = [:]
    ) -> String? {
        let clauses = text
            .split(whereSeparator: \.isWhitespace)
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
            .map { clause(for: $0, abbreviations: abbreviations) }

        return clauses.isEmpty ? nil : clauses.joined(separator: " ")
    }

    private static func clause(
        for token: some StringProtocol,
        abbreviations: [String: String]
    ) -> String {
        let literal = prefixTerm(token)
        guard let expansion = ClinicalAbbreviations.expansion(for: token, adding: abbreviations)
        else {
            return literal
        }

        let expanded = expansion
            .split(whereSeparator: \.isWhitespace)
            .map(prefixTerm)
            .joined(separator: " ")

        return "(\(literal) OR (\(expanded)))"
    }

    private static func prefixTerm(_ token: some StringProtocol) -> String {
        "\"\(token.replacingOccurrences(of: "\"", with: "\"\""))\"*"
    }
}
