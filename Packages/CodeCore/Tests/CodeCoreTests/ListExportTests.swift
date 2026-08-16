import Testing
@testable import CodeCore

@Suite("Exporting a list")
struct ListExportTests {

    private let diabetes = ClinicalCode(
        code: "E11.9", display: "Type 2 diabetes mellitus without complications",
        system: .icd10cm, isBillable: true
    )
    private let asthma = ClinicalCode(
        code: "J45.909", display: "Unspecified asthma, uncomplicated",
        system: .icd10cm, isBillable: true
    )
    private let header = ClinicalCode(
        code: "E11", display: "Type 2 diabetes mellitus",
        system: .icd10cm, isBillable: false
    )
    private let unknown = ClinicalCode(
        code: "A00", display: "Cholera", system: .icd10cm
    )

    // MARK: - Text

    @Test("should write one line per code")
    func textIsOneLinePerCode() {
        let exported = ListExportFormat.text.string(for: [diabetes, asthma])

        #expect(exported.split(separator: "\n").count == 2)
    }

    /// The same wording ⇧Return writes for a single code, so a pasted list reads
    /// like the codes a clinician has pasted one at a time.
    @Test("should word a line exactly as copying one code does")
    func textMatchesTheSingleCodeWording() {
        let exported = ListExportFormat.text.string(for: [diabetes])

        #expect(exported == CopyFormat.codeAndDisplay.string(for: diabetes))
    }

    // MARK: - CSV

    @Test("should give the CSV a header row")
    func csvHasHeader() {
        let first = ListExportFormat.csv.string(for: [diabetes]).split(separator: "\n").first

        #expect(first == "Code,Description,System,Billable")
    }

    @Test("should write one CSV row per code, after the header")
    func csvIsOneRowPerCode() {
        let exported = ListExportFormat.csv.string(for: [diabetes, asthma])

        #expect(exported.split(separator: "\n").count == 3)
    }

    /// The failure this format exists to avoid: ICD-10-CM descriptions are full
    /// of commas, so an unescaped export puts half of nearly every description in
    /// the wrong column.
    @Test("should quote a description containing a comma")
    func csvQuotesCommas() {
        let exported = ListExportFormat.csv.string(for: [asthma])

        #expect(exported.contains("\"Unspecified asthma, uncomplicated\""))
    }

    @Test("should leave a description without a comma unquoted")
    func csvLeavesPlainFieldsAlone() {
        let exported = ListExportFormat.csv.string(for: [unknown])

        #expect(exported.contains(",Cholera,"))
    }

    @Test("should double a quote inside a field rather than end it early")
    func csvDoublesQuotes() {
        let quoted = ClinicalCode(
            code: "X00", display: "So-called \"mild\" case", system: .icd10cm
        )

        let exported = ListExportFormat.csv.string(for: [quoted])

        #expect(exported.contains("\"So-called \"\"mild\"\" case\""))
    }

    @Test("should mark a billable code yes")
    func csvMarksBillable() {
        #expect(ListExportFormat.csv.string(for: [diabetes]).hasSuffix(",yes"))
    }

    @Test("should mark a category header no")
    func csvMarksHeader() {
        #expect(ListExportFormat.csv.string(for: [header]).hasSuffix(",no"))
    }

    /// Silence is not a "no". A category header must never reach a claim, so
    /// writing `no` for a code the publisher said nothing about would turn an
    /// unknown into a statement.
    @Test("should leave billability empty when the publisher did not say")
    func csvLeavesUnknownBillabilityEmpty() {
        #expect(ListExportFormat.csv.string(for: [unknown]).hasSuffix(","))
    }

    // MARK: - Edges

    @Test("should still produce a usable CSV for an empty list")
    func csvOfEmptyListIsJustTheHeader() {
        #expect(ListExportFormat.csv.string(for: []) == "Code,Description,System,Billable")
    }

    @Test("should produce nothing for an empty list as text")
    func textOfEmptyListIsEmpty() {
        #expect(ListExportFormat.text.string(for: []).isEmpty)
    }

    @Test("should name the file after the format")
    func fileExtensionsDiffer() {
        #expect(ListExportFormat.csv.fileExtension == "csv")
        #expect(ListExportFormat.text.fileExtension == "txt")
    }
}
