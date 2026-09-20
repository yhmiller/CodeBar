public enum CopyFormat: String, Codable, CaseIterable, Sendable {
    case codeOnly
    case codeAndDisplay

    public func string(for code: ClinicalCode) -> String {
        switch self {
        case .codeOnly:
            code.code
        case .codeAndDisplay:
            "\(code.system.rawValue) \(code.code) — \(code.display)"
        }
    }

    public var label: String {
        switch self {
        case .codeOnly: "Code only"
        case .codeAndDisplay: "Code with description"
        }
    }
}
