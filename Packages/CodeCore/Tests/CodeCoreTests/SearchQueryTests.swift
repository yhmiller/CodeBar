import Testing
@testable import CodeCore

@Suite("SearchQuery")
struct SearchQueryTests {

    @Test("should quote each token and append a prefix operator")
    func quotesAndPrefixesTokens() {
        #expect(SearchQuery.matchExpression(for: "type 2 diabetes") == "\"type\"* \"2\"* \"diabetes\"*")
    }

    @Test("should quote a hyphenated term rather than treat it as FTS negation")
    func quotesHyphenatedTerm() {
        #expect(SearchQuery.matchExpression(for: "non-hodgkin") == "\"non-hodgkin\"*")
    }

    @Test("should escape an embedded double quote by doubling it")
    func escapesEmbeddedQuote() {
        #expect(SearchQuery.matchExpression(for: "a\"b") == "\"a\"\"b\"*")
    }

    @Test("should drop tokens with no alphanumeric content")
    func dropsPunctuationOnlyTokens() {
        #expect(SearchQuery.matchExpression(for: "- diabetes") == "\"diabetes\"*")
    }

    @Test("should produce no match expression for a blank query")
    func noMatchExpressionForBlankQuery() {
        #expect(SearchQuery.matchExpression(for: "   ") == nil)
    }

    @Test("should report a whitespace-only query as empty")
    func whitespaceQueryIsEmpty() {
        #expect(SearchQuery(raw: "   ").isEmpty)
    }

    @Test("should normalize the raw query for code matching")
    func normalizesRawQuery() {
        #expect(SearchQuery(raw: " e11.9 ").normalizedCode == "E119")
    }
}
