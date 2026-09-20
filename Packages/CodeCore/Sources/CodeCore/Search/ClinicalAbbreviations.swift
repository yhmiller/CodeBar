public enum ClinicalAbbreviations {

    public static let expansions: [String: String] = [
        "afib": "atrial fibrillation",
        "aki": "acute kidney failure",
        "bph": "benign prostatic hyperplasia",
        "cad": "coronary artery disease",
        "chf": "heart failure",
        "ckd": "chronic kidney disease",
        "copd": "chronic obstructive pulmonary disease",
        "cva": "cerebral infarction",
        "dm": "diabetes mellitus",
        "dvt": "deep vein thrombosis",
        "esrd": "end stage renal disease",
        "gad": "generalized anxiety disorder",
        "gerd": "gastro-esophageal reflux disease",
        "htn": "hypertension",
        "ibs": "irritable bowel syndrome",
        "oa": "osteoarthritis",
        "osa": "obstructive sleep apnea",
        "pud": "peptic ulcer",
        "pvd": "peripheral vascular disease",
        "ra": "rheumatoid arthritis",
        "sob": "shortness of breath",
        "t1dm": "type 1 diabetes mellitus",
        "t2dm": "type 2 diabetes mellitus",
        "tia": "transient cerebral ischemic attack",
        "uri": "upper respiratory infection",
        "uti": "urinary tract infection"
    ]

    public static func expansion(
        for token: some StringProtocol,
        adding own: [String: String] = [:]
    ) -> String? {
        let key = token.lowercased()
        return own[key] ?? expansions[key]
    }
}
