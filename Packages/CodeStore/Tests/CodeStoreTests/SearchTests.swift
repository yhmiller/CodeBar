import CodeCore
import Testing
@testable import CodeStore

@Suite("Search")
struct SearchTests {

    @Test("should return no results for a blank query")
    func blankQueryReturnsNothing() async throws {
        let store = try await Fixtures.seededStore()

        #expect(try await store.search(SearchQuery(raw: "   ")).isEmpty)
    }

    @Test("should find a dotted code when the query omits the dot")
    func undottedQueryFindsDottedCode() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "E119"))

        #expect(results.contains { $0.code.code == "E11.9" })
    }

    @Test("should find a hyphenated LOINC code when the query omits the hyphen")
    func unhyphenatedQueryFindsLoincCode() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "21600"))

        #expect(results.contains { $0.code.code == "2160-0" })
    }

    @Test("should match a code prefix regardless of query case")
    func codePrefixIsCaseInsensitive() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "e11"))

        #expect(results.contains { $0.code.code == "E11.65" })
    }

    @Test("should tag a whole-code match as an exact-code hit")
    func exactCodeMatchIsTaggedExact() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "E11"))

        #expect(results.first?.matchTier == .exactCode)
    }

    @Test("should place the exact code match first")
    func exactCodeMatchRanksFirst() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "E11"))

        #expect(results.first?.code.code == "E11")
    }

    @Test("should tag a partial code match as a prefix hit")
    func partialCodeMatchIsTaggedPrefix() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "E11"))

        #expect(results.first(where: { $0.code.code == "E11.9" })?.matchTier == .codePrefix)
    }

    @Test("should return results ordered by ascending match tier")
    func resultsAreOrderedByTier() async throws {
        let store = try await Fixtures.seededStore()

        let tiers = try await store.search(SearchQuery(raw: "E11")).map(\.matchTier)

        #expect(tiers == tiers.sorted())
    }

    @Test("should tag a description match as a text hit")
    func descriptionMatchIsTaggedText() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "hypertension"))

        #expect(results.first?.matchTier == .text)
    }

    @Test("should find a code by a word in its description")
    func findsCodeByDescriptionWord() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "hypertension"))

        #expect(results.first?.code.code == "I10")
    }

    @Test("should find a code by a partial word in its description")
    func findsCodeByDescriptionPrefix() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "hyperten"))

        #expect(results.contains { $0.code.code == "I10" })
    }

    @Test("should find a code by a multi-word synonym")
    func findsCodeByMultiWordSynonym() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "high blood pressure"))

        #expect(results.contains { $0.code.code == "I10" })
    }

    @Test("should return a multi-word synonym intact rather than split into tokens")
    func multiWordSynonymSurvivesRoundTrip() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "I10"))

        #expect(results.first?.code.synonyms == ["high blood pressure"])
    }

    @Test("should return each code once when it matches both passes")
    func resultsAreDeduplicated() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "E11"))
        let codes = results.map(\.code.code)

        #expect(codes.count == Set(codes).count)
    }

    @Test("should exclude systems not named in the query")
    func filtersToRequestedSystems() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(
            SearchQuery(raw: "creatinine", systems: [.icd10cm])
        )

        #expect(results.isEmpty)
    }

    @Test("should include a system named in the query")
    func includesRequestedSystem() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(
            SearchQuery(raw: "creatinine", systems: [.loinc])
        )

        #expect(results.first?.code.code == "2160-0")
    }

    @Test("should cap the result count at the requested limit")
    func respectsResultLimit() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "diabetes", limit: 2))

        #expect(results.count == 2)
    }

    @Test("should treat a hyphenated term as text rather than FTS negation")
    func hyphenatedTermDoesNotBreakTheQuery() async throws {
        let store = try await Fixtures.seededStore()

        let results = try await store.search(SearchQuery(raw: "Mass/volume"))

        #expect(results.contains { $0.code.code == "2160-0" })
    }

    @Test("should return no results rather than throwing for punctuation-only input")
    func punctuationOnlyQueryReturnsNothing() async throws {
        let store = try await Fixtures.seededStore()

        #expect(try await store.search(SearchQuery(raw: "-- ()")).isEmpty)
    }
}
