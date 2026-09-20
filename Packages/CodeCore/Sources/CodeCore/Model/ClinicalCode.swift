public struct ClinicalCode: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(system.rawValue)-\(code)" }

    public let code: String
    public let display: String
    public let system: CodeSystem
    public let synonyms: [String]
    public let isBillable: Bool?
    public let parent: String?
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
