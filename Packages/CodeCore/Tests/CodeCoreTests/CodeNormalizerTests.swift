import Testing
@testable import CodeCore

@Suite("CodeNormalizer")
struct CodeNormalizerTests {

    @Test("should uppercase and strip punctuation from a dotted code")
    func normalizesDottedCode() {
        #expect(CodeNormalizer.normalize("e11.9") == "E119")
    }

    @Test("should leave an already normalized code unchanged")
    func leavesNormalizedCodeUnchanged() {
        #expect(CodeNormalizer.normalize("E119") == "E119")
    }

    @Test("should strip hyphens and spaces")
    func stripsHyphensAndSpaces() {
        #expect(CodeNormalizer.normalize("2160-0 ") == "21600")
    }

    @Test("should return empty string when input has no alphanumerics")
    func returnsEmptyForPunctuationOnly() {
        #expect(CodeNormalizer.normalize("...--") == "")
    }

    @Test("should increment the last character to form a prefix upper bound")
    func incrementsLastCharacterForUpperBound() {
        #expect(CodeNormalizer.prefixUpperBound("E11") == "E12")
    }

    @Test("should carry past Z when forming a prefix upper bound")
    func upperBoundPastZ() {
        #expect(CodeNormalizer.prefixUpperBound("EZ") == "E[")
    }

    @Test("should return nil upper bound for an empty prefix")
    func noUpperBoundForEmptyPrefix() {
        #expect(CodeNormalizer.prefixUpperBound("") == nil)
    }
}
