/// Expands clinical shorthand into the words a code description actually uses.
///
/// `UTI` appears in no ICD-10-CM description, so searching for it finds nothing
/// however well the results are ranked — a code has to *match* before ranking can
/// help. CMS's alphabetic index carries a handful of abbreviations (`GERD`) but
/// not the everyday ones.
///
/// This expands the **query**, not the code. Searching `uti` behaves like
/// searching `urinary tract infection`, and the normal ranking then decides which
/// code fits. That distinction matters: mapping an abbreviation to a specific
/// code would be a clinical judgement made on the user's behalf, and a wrong one
/// puts a wrong code on a claim. Mapping it to its own expansion is a fact about
/// vocabulary, and the clinician still chooses from what comes back.
///
/// Only abbreviations whose expansion is not seriously contested belong here.
/// Anything where the reading depends on specialty or context is deliberately
/// left out — a clinician's own shorthand is theirs to add, not ours to guess.
public enum ClinicalAbbreviations {

    /// Lowercase abbreviation to the phrase a description would use.
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

    /// The expansion for a single query token, if there is one.
    ///
    /// The clinician's own entries win over the built-in table. That is the
    /// point rather than a conflict to resolve: `RA` is rheumatoid arthritis on
    /// most wards and the right atrium on some, and only the person typing it
    /// knows which they meant.
    public static func expansion(
        for token: some StringProtocol,
        adding own: [String: String] = [:]
    ) -> String? {
        let key = token.lowercased()
        return own[key] ?? expansions[key]
    }
}
