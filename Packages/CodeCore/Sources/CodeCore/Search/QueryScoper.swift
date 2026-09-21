import Foundation

/// The result of parsing a raw search query for taxonomy scoping tags (e.g. `@cpt`, `@loinc`).
public struct ScopedQueryParseResult: Equatable, Sendable {
    public let cleanText: String
    public let scopedSystem: CodeSystem?
    public let tag: String?

    public init(cleanText: String, scopedSystem: CodeSystem?, tag: String?) {
        self.cleanText = cleanText
        self.scopedSystem = scopedSystem
        self.tag = tag
    }
}

/// Parses and extracts system-scoping prefixes/tags from clinical search inputs.
public enum QueryScoper {
    private static let systemByTag: [String: CodeSystem] = [
        // CPT
        "@cpt": .cpt,
        "#cpt": .cpt,

        // LOINC
        "@loinc": .loinc,
        "#loinc": .loinc,
        "@lab": .loinc,
        "#lab": .loinc,
        "@labs": .loinc,
        "#labs": .loinc,

        // ICD-10
        "@icd": .icd10cm,
        "#icd": .icd10cm,
        "@icd10": .icd10cm,
        "#icd10": .icd10cm,
        "@icd-10": .icd10cm,
        "#icd-10": .icd10cm,
        "@dx": .icd10cm,
        "#dx": .icd10cm,

        // SNOMED
        "@snomed": .snomed,
        "#snomed": .snomed,
        "@snomedct": .snomed,
        "#snomedct": .snomed
    ]

    /// Parses the raw user query, extracting any clinical system scope tag and leaving pure search terms.
    public static func parse(_ raw: String) -> ScopedQueryParseResult {
        let tokens = raw.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var detectedSystem: CodeSystem?
        var detectedTag: String?
        var remainingTokens: [String] = []

        for token in tokens {
            let normalizedToken = token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":="))
            if detectedSystem == nil, let system = systemByTag[normalizedToken] {
                detectedSystem = system
                detectedTag = token
            } else {
                remainingTokens.append(token)
            }
        }

        let cleanText = remainingTokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return ScopedQueryParseResult(
            cleanText: cleanText,
            scopedSystem: detectedSystem,
            tag: detectedTag
        )
    }

    /// Returns the canonical shorthand tag for a clinical code system.
    public static func defaultTag(for system: CodeSystem) -> String {
        switch system {
        case .cpt: "@cpt"
        case .loinc: "@loinc"
        case .icd10cm: "@icd"
        case .snomed: "@snomed"
        }
    }
}
