/// A single code in a clinical terminology.
///
/// `Codable` conformance defines the on-disk JSON interchange format consumed by
/// `Scripts/import_*.py` output — renaming a property is a breaking format change.
public struct ClinicalCode: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(system.rawValue)-\(code)" }

    /// Display form, punctuation included: `E11.9`.
    public let code: String
    public let display: String
    public let system: CodeSystem
    public let synonyms: [String]

    /// Whether the publisher marks this code as valid to submit on a claim.
    ///
    /// `nil` when the source does not carry the information — LOINC and SNOMED
    /// have no billability concept, and code sets imported before this field
    /// existed cannot say either way.
    ///
    /// This matters clinically. ICD-10-CM contains category headers such as
    /// `E11` "Type 2 diabetes mellitus" that are *not* submittable: they require
    /// a further character (`E11.9`). A header copied onto a claim is a denial,
    /// and nothing in the code itself distinguishes the two — `A09` and `I10`
    /// are three characters and perfectly billable.
    public let isBillable: Bool?

    /// The code one level up, e.g. `E11.2` for `E11.21`.
    ///
    /// Read from the publisher's tabular file, not derived: `E11.21`'s parent is
    /// `E11.2`, not `E11`, so trimming the last character would build a wrong
    /// tree. `nil` for a top-level code, or when the source carried no hierarchy.
    public let parent: String?

    /// The chapter this code sits in, for grouping when browsing.
    public let chapter: String?

    public init(
        code: String,
        display: String,
        system: CodeSystem,
        synonyms: [String] = [],
        isBillable: Bool? = nil,
        parent: String? = nil,
        chapter: String? = nil
    ) {
        self.code = code
        self.display = display
        self.system = system
        self.synonyms = synonyms
        self.isBillable = isBillable
        self.parent = parent
        self.chapter = chapter
    }

    /// Search form, punctuation stripped: `E119`. Lets a query typed without
    /// dots still match the stored code.
    public var normalizedCode: String {
        CodeNormalizer.normalize(code)
    }

    private enum CodingKeys: String, CodingKey {
        case code, display, system, synonyms, billable, parent, chapter, notes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        display = try container.decode(String.self, forKey: .display)
        system = try container.decode(CodeSystem.self, forKey: .system)
        synonyms = try container.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        isBillable = try container.decodeIfPresent(Bool.self, forKey: .billable)
        parent = try container.decodeIfPresent(String.self, forKey: .parent)
        chapter = try container.decodeIfPresent(String.self, forKey: .chapter)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(display, forKey: .display)
        try container.encode(system, forKey: .system)
        try container.encode(synonyms, forKey: .synonyms)
        try container.encodeIfPresent(isBillable, forKey: .billable)
        try container.encodeIfPresent(parent, forKey: .parent)
        try container.encodeIfPresent(chapter, forKey: .chapter)
    }
}
