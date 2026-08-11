import Foundation
import Testing
@testable import CodeCore

@Suite("Clinical abbreviations")
struct AbbreviationTests {

    @Test("should expand a known abbreviation alongside the literal token")
    func expandsKnownAbbreviation() {
        let expression = SearchQuery.matchExpression(for: "uti")

        #expect(expression == #"("uti"* OR ("urinary"* "tract"* "infection"*))"#)
    }

    @Test("should keep the abbreviation itself searchable")
    func keepsLiteralToken() {
        // A code set that does spell out GERD should still match someone typing it.
        #expect(SearchQuery.matchExpression(for: "gerd")?.contains(#""gerd"*"#) == true)
    }

    @Test("should leave an unknown word alone")
    func leavesUnknownWordAlone() {
        #expect(SearchQuery.matchExpression(for: "diabetes") == #""diabetes"*"#)
    }

    @Test("should expand an abbreviation used within a longer query")
    func expandsWithinAPhrase() {
        let expression = SearchQuery.matchExpression(for: "acute uti")

        #expect(expression == #""acute"* ("uti"* OR ("urinary"* "tract"* "infection"*))"#)
    }

    @Test("should expand regardless of case")
    func isCaseInsensitive() {
        #expect(SearchQuery.matchExpression(for: "UTI")?.contains(#""urinary"*"#) == true)
    }

    @Test("should expand each abbreviation in a query with two")
    func expandsSeveral() {
        let expression = SearchQuery.matchExpression(for: "copd htn")

        #expect(expression?.contains("pulmonary") == true
                && expression?.contains("hypertension") == true)
    }

    @Test("should keep every expansion lowercase and non-empty")
    func expansionsAreWellFormed() {
        let malformed = ClinicalAbbreviations.expansions.filter { key, value in
            key != key.lowercased() || value.trimmingCharacters(in: .whitespaces).isEmpty
        }

        #expect(malformed.isEmpty)
    }

    @Test("should not map an abbreviation to a code")
    func expansionsAreWordsNotCodes() {
        // Mapping shorthand to a specific code would be a clinical judgement made
        // for the user. Every expansion must be prose.
        let codeLike = ClinicalAbbreviations.expansions.values.filter {
            $0.contains(".") || $0.first?.isNumber == true
        }

        #expect(codeLike.isEmpty)
    }
}
