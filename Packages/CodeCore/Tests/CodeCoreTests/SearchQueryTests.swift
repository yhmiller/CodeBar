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

    @Test("should parse system scope tag and strip it from clean text")
    func parsesSystemTags() {
        let cptQuery = SearchQuery(raw: "@cpt 99214")
        #expect(cptQuery.scopedSystem == .cpt)
        #expect(cptQuery.text == "99214")
        #expect(cptQuery.systems == [.cpt])
        #expect(cptQuery.matchExpression == "\"99214\"*")

        let loincQuery = SearchQuery(raw: "@loinc glucose")
        #expect(loincQuery.scopedSystem == .loinc)
        #expect(loincQuery.text == "glucose")
        #expect(loincQuery.systems == [.loinc])

        let icdQuery = SearchQuery(raw: "@icd diabetes")
        #expect(icdQuery.scopedSystem == .icd10cm)
        #expect(icdQuery.text == "diabetes")
        #expect(icdQuery.systems == [.icd10cm])

        let snomedQuery = SearchQuery(raw: "@snomed asthma")
        #expect(snomedQuery.scopedSystem == .snomed)
        #expect(snomedQuery.text == "asthma")
        #expect(snomedQuery.systems == [.snomed])
    }

    @Test("should support system aliases and hash tags")
    func supportsAliasesAndHashtags() {
        #expect(SearchQuery(raw: "@lab a1c").scopedSystem == .loinc)
        #expect(SearchQuery(raw: "@labs potassium").scopedSystem == .loinc)
        #expect(SearchQuery(raw: "#cpt 99213").scopedSystem == .cpt)
        #expect(SearchQuery(raw: "@dx hypertension").scopedSystem == .icd10cm)
        #expect(SearchQuery(raw: "@icd10 E11").scopedSystem == .icd10cm)
        #expect(SearchQuery(raw: "#snomed 195967001").scopedSystem == .snomed)
    }

    @Test("should handle tag anywhere in query")
    func tagAnywhereInQuery() {
        let trailing = SearchQuery(raw: "99214 @cpt")
        #expect(trailing.scopedSystem == .cpt)
        #expect(trailing.text == "99214")

        let middle = SearchQuery(raw: "blood @lab glucose")
        #expect(middle.scopedSystem == .loinc)
        #expect(middle.text == "blood glucose")
    }

    @Test("should mark standalone tag query as empty")
    func standaloneTagIsEmpty() {
        let query = SearchQuery(raw: "@cpt")
        #expect(query.scopedSystem == .cpt)
        #expect(query.text.isEmpty)
        #expect(query.isEmpty)
        #expect(query.systems == [.cpt])
    }
}
