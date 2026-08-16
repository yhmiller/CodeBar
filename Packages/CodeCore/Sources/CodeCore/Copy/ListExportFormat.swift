/// How a saved list leaves CodeBar.
///
/// A curated list is worth little if it can only be read inside the app that
/// holds it. These are the two shapes it is actually wanted in: pasted into a
/// note, or opened in a spreadsheet.
public enum ListExportFormat: String, CaseIterable, Sendable {

    /// One line per code, worded exactly as ⇧Return writes a single one.
    ///
    /// Deliberately the same wording rather than a third one: a clinician who
    /// has pasted one code should recognise a pasted list.
    case text

    /// RFC 4180, for a spreadsheet.
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

    /// Empty for unknown, which is not the same as "no".
    ///
    /// Billability is three-state: the publisher says a code is submittable, says
    /// it is a category header, or does not say. Writing `no` for the third would
    /// turn a silence into a claim, and the whole point of the field is that a
    /// category header must never reach a claim form.
    private static func billableField(for code: ClinicalCode) -> String {
        switch code.isBillable {
        case true: "yes"
        case false: "no"
        case nil: ""
        }
    }

    /// RFC 4180: a field containing a comma, a quote or a newline is wrapped in
    /// quotes, and any quote inside it is doubled.
    ///
    /// Not optional politeness — ICD-10-CM descriptions are full of commas
    /// ("Unspecified asthma, uncomplicated"), so an unescaped export would put
    /// the second half of nearly every description in the wrong column.
    private static func escaped(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" })
        else { return field }

        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
