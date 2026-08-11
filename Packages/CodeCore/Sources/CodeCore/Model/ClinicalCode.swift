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

    public init(code: String, display: String, system: CodeSystem, synonyms: [String] = []) {
        self.code = code
        self.display = display
        self.system = system
        self.synonyms = synonyms
    }

    /// Search form, punctuation stripped: `E119`. Lets a query typed without
    /// dots still match the stored code.
    public var normalizedCode: String {
        CodeNormalizer.normalize(code)
    }

    private enum CodingKeys: String, CodingKey {
        case code, display, system, synonyms
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        display = try container.decode(String.self, forKey: .display)
        system = try container.decode(CodeSystem.self, forKey: .system)
        synonyms = try container.decodeIfPresent([String].self, forKey: .synonyms) ?? []
    }
}
