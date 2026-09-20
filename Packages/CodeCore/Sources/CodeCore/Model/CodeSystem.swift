public enum CodeSystem: String, Codable, CaseIterable, Sendable {
    case icd10cm = "ICD-10-CM"
    case loinc = "LOINC"
    case snomed = "SNOMED CT"
    case cpt = "CPT"

    public var shortLabel: String {
        switch self {
        case .icd10cm: "ICD-10"
        case .loinc: "LOINC"
        case .snomed: "SNOMED"
        case .cpt: "CPT"
        }
    }
}
