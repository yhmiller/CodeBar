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
        let codeLike = ClinicalAbbreviations.expansions.values.filter {
            $0.contains(".") || $0.first?.isNumber == true
        }

        #expect(codeLike.isEmpty)
    }
}

@Suite("A clinician's own abbreviations")
struct OwnAbbreviationTests {

    @Test("should expand a term the built-in table does not know")
    func expandsOwnTerm() {
        let expression = SearchQuery.matchExpression(
            for: "pcn", abbreviations: ["pcn": "penicillin"]
        )

        #expect(expression == #"("pcn"* OR ("penicillin"*))"#)
    }

    @Test("should let the user's own entry override a built-in")
    func ownEntryWinsOverBuiltIn() {
        let expression = SearchQuery.matchExpression(
            for: "ra", abbreviations: ["ra": "right atrium"]
        )

        #expect(expression?.contains(#""right"* "atrium"*"#) == true)
        #expect(expression?.contains("rheumatoid") == false)
    }

    @Test("should still expand built-ins the user has not overridden")
    func leavesOtherBuiltInsAlone() {
        let expression = SearchQuery.matchExpression(
            for: "uti", abbreviations: ["pcn": "penicillin"]
        )

        #expect(expression?.contains(#""urinary"*"#) == true)
    }

    @Test("should expand the user's own term regardless of the case typed")
    func ownTermIsCaseInsensitive() {
        let expression = SearchQuery.matchExpression(
            for: "PCN", abbreviations: ["pcn": "penicillin"]
        )

        #expect(expression?.contains(#""penicillin"*"#) == true)
    }

    @Test("should reach the query built by a caller, not only the helper")
    func searchQueryCarriesOwnAbbreviations() {
        let query = SearchQuery(raw: "pcn", abbreviations: ["pcn": "penicillin"])

        #expect(query.matchExpression?.contains(#""penicillin"*"#) == true)
    }
}

@Suite("Abbreviation")
struct AbbreviationValueTests {

    @Test("should lowercase the term so lookup finds it")
    func lowercasesTerm() {
        #expect(Abbreviation(term: "PCN", expansion: "penicillin").term == "pcn")
    }

    @Test("should trim surrounding whitespace from a typed term")
    func trimsTerm() {
        #expect(Abbreviation(term: "  pcn  ", expansion: "penicillin").term == "pcn")
    }

    @Test("should reject an entry with no term")
    func rejectsBlankTerm() {
        #expect(Abbreviation(term: "   ", expansion: "penicillin").isUsable == false)
    }

    @Test("should reject an entry with no expansion")
    func rejectsBlankExpansion() {
        #expect(Abbreviation(term: "pcn", expansion: " ").isUsable == false)
    }

    @Test("should drop unusable entries when collapsing to a lookup table")
    func skipsUnusableWhenCollapsing() {
        let table = [
            Abbreviation(term: "pcn", expansion: "penicillin"),
            Abbreviation(term: "", expansion: "nonsense")
        ].expansionsByTerm

        #expect(table == ["pcn": "penicillin"])
    }
}
