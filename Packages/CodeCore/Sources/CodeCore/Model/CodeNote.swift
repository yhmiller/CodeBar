/// A clinical note attached to a code by the publisher.
///
/// These are not decoration. `excludes1` and `excludes2` look alike and mean
/// opposite things: excludes1 says the two conditions cannot occur together and
/// must never both be coded, while excludes2 says the condition is separate and
/// both may legitimately be coded. Collapsing them would be a coding error
/// waiting to happen, so the distinction is carried all the way through.
public struct CodeNote: Codable, Hashable, Sendable {

    public enum Kind: String, Codable, Sendable, CaseIterable {
        /// Terms this code covers.
        case includes
        /// Alternative wordings that map here.
        case inclusionTerm
        /// Never code together with this code.
        case excludes1
        /// Separate condition; both may be coded.
        case excludes2
        /// Sequence the underlying condition first.
        case codeFirst
        /// Add a further code to describe detail.
        case useAdditionalCode
        /// A related code that may also apply.
        case codeAlso
        /// Anything else the publisher attached.
        case note

        /// How it should be labelled in the UI.
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

        /// Whether getting this wrong produces an invalid claim.
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

/// Everything known about one code — what a detail view needs.
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
