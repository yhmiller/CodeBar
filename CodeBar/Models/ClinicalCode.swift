import Foundation

struct ClinicalCode: Identifiable, Codable, Hashable {
    var id: String { "\(system.rawValue)-\(code)" }
    let code: String
    let display: String
    let system: CodeSystem
    let synonyms: [String]

    enum CodeSystem: String, Codable, CaseIterable {
        case icd10cm = "ICD-10-CM"
        case loinc = "LOINC"
        case snomed = "SNOMED CT"
        case cpt = "CPT"

        var shortLabel: String {
            switch self {
            case .icd10cm: return "ICD-10"
            case .loinc: return "LOINC"
            case .snomed: return "SNOMED"
            case .cpt: return "CPT"
            }
        }
    }
}
