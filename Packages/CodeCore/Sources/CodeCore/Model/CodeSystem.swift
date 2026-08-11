/// The clinical terminologies CodeBar can search.
///
/// Raw values are the canonical system names used in the JSON interchange
/// format and stored verbatim in the database, so they must stay stable.
public enum CodeSystem: String, Codable, CaseIterable, Sendable {
    case icd10cm = "ICD-10-CM"
    case loinc = "LOINC"
    case snomed = "SNOMED CT"
    case cpt = "CPT"

    /// Short form for the result-row badge, where horizontal space is tight.
    public var shortLabel: String {
        switch self {
        case .icd10cm: "ICD-10"
        case .loinc: "LOINC"
        case .snomed: "SNOMED"
        case .cpt: "CPT"
        }
    }
}
