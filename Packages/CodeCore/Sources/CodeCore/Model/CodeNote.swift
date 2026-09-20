public struct CodeNote: Codable, Hashable, Sendable {

    public enum Kind: String, Codable, Sendable, CaseIterable {
        case includes
        case inclusionTerm
        case excludes1
        case excludes2
        case codeFirst
        case useAdditionalCode
        case codeAlso
        case note

        public var label: String {
            switch self {
            case .includes: "Includes"
            case .inclusionTerm: "Also called"
            case .excludes1: "Excludes 1 — never code together"
            case .excludes2: "Excludes 2 — may code both"
            case .codeFirst: "Code first"
            case .useAdditionalCode: "Use additional code"
            case .codeAlso: "Code also"
            case .note: "Note"
            }
        }

        public var isCodingRule: Bool {
            switch self {
            case .excludes1, .excludes2, .codeFirst, .useAdditionalCode, .codeAlso: true
            case .includes, .inclusionTerm, .note: false
            }
        }
    }

    public let kind: Kind
    public let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}

public struct CodeDetail: Sendable, Equatable {
    public let code: ClinicalCode
    public let ancestors: [ClinicalCode]
    public let children: [ClinicalCode]
    public let notes: [CodeNote]

    public init(code: ClinicalCode, ancestors: [ClinicalCode],
                children: [ClinicalCode], notes: [CodeNote]) {
        self.code = code
        self.ancestors = ancestors
        self.children = children
        self.notes = notes
    }
}
