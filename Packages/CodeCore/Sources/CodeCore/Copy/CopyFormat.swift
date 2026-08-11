/// How a chosen code is written to the pasteboard.
public enum CopyFormat: String, Codable, CaseIterable, Sendable {
    /// Just the code: `E11.9`. What Return does.
    case codeOnly
    /// `ICD-10-CM E11.9 — Type 2 diabetes mellitus without complications`.
    /// What ⇧Return does, for pasting into a note rather than a code field.
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
