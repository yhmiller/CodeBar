public enum ListExportFormat: String, CaseIterable, Sendable {

    case text
    case csv

    public var label: String {
        switch self {
        case .text: "Plain text"
        case .csv: "CSV"
        }
    }

    public var fileExtension: String {
        rawValue == "csv" ? "csv" : "txt"
    }

    public func string(for codes: [ClinicalCode]) -> String {
        switch self {
        case .text:
            codes.map(CopyFormat.codeAndDisplay.string(for:)).joined(separator: "\n")
        case .csv:
            ([Self.csvHeader] + codes.map(Self.csvRow)).joined(separator: "\n")
        }
    }

    // MARK: - CSV

    private static let csvHeader = "Code,Description,System,Billable"

    private static func csvRow(for code: ClinicalCode) -> String {
        [
            code.code,
            code.display,
            code.system.rawValue,
            billableField(for: code)
        ]
        .map(escaped)
        .joined(separator: ",")
    }

    private static func billableField(for code: ClinicalCode) -> String {
        switch code.isBillable {
        case true: "yes"
        case false: "no"
        case nil: ""
        }
    }

    private static func escaped(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" })
        else { return field }

        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
