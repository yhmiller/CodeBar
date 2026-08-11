import CodeCore
import Foundation
import Testing
@testable import CodeStore

@Suite("Envelope format")
struct EnvelopeTests {

    private func envelope(
        version: Int = 1,
        system: String = "ICD-10-CM",
        release: String = "2026",
        mode: String = "replace",
        codes: String = #"{"code":"E11.9","display":"Type 2 diabetes","system":"ICD-10-CM"}"#
    ) -> Data {
        Data("""
        {"formatVersion": \(version), "system": "\(system)", "release": "\(release)",
         "mode": "\(mode)", "codes": [\(codes)]}
        """.utf8)
    }

    @Test("should read the codes out of an envelope")
    func readsEnvelopeCodes() throws {
        #expect(try CodeSetDecoder.decode(envelope()).codes.first?.code == "E11.9")
    }

    @Test("should carry the publisher's release through")
    func readsRelease() throws {
        #expect(try CodeSetDecoder.decode(envelope()).release == "2026")
    }

    @Test("should honour a replace request")
    func readsReplaceMode() throws {
        #expect(try CodeSetDecoder.decode(envelope(mode: "replace")).mode == .replace)
    }

    @Test("should honour a merge request")
    func readsMergeMode() throws {
        #expect(try CodeSetDecoder.decode(envelope(mode: "merge")).mode == .merge)
    }

    @Test("should default an envelope without a mode to merging")
    func defaultsToMergeWhenModeAbsent() throws {
        let data = Data(#"""
        {"formatVersion":1,"codes":[{"code":"I10","display":"Hypertension","system":"ICD-10-CM"}]}
        """#.utf8)

        #expect(try CodeSetDecoder.decode(data).mode == .merge)
    }

    @Test("should still read the legacy bare-array format")
    func readsLegacyBareArray() throws {
        let data = Data(#"[{"code":"I10","display":"Hypertension","system":"ICD-10-CM"}]"#.utf8)

        #expect(try CodeSetDecoder.decode(data).codes.first?.code == "I10")
    }

    @Test("should never replace on the strength of a legacy file")
    func legacyFilesAlwaysMerge() throws {
        let data = Data(#"[{"code":"I10","display":"Hypertension","system":"ICD-10-CM"}]"#.utf8)

        #expect(try CodeSetDecoder.decode(data).mode == .merge)
    }

    @Test("should reject a format version this build does not understand")
    func rejectsNewerFormatVersion() throws {
        #expect(throws: CodeSetDecoder.DecodingError.unsupportedFormatVersion(2)) {
            _ = try CodeSetDecoder.decode(envelope(version: 2))
        }
    }

    @Test("should reject a file whose declared system disagrees with its codes")
    func rejectsSystemMismatch() throws {
        let data = envelope(
            system: "LOINC",
            codes: #"{"code":"E11.9","display":"Type 2 diabetes","system":"ICD-10-CM"}"#
        )

        #expect(throws: CodeSetDecoder.DecodingError.systemMismatch(declared: .loinc, found: .icd10cm)) {
            _ = try CodeSetDecoder.decode(data)
        }
    }

    @Test("should reject an envelope with no codes")
    func rejectsEmptyEnvelope() throws {
        #expect(throws: CodeSetDecoder.DecodingError.empty) {
            _ = try CodeSetDecoder.decode(Data(#"{"formatVersion":1,"codes":[]}"#.utf8))
        }
    }

    @Test("should tolerate leading whitespace when detecting the shape")
    func tolerantOfLeadingWhitespace() throws {
        var data = Data("\n  \t".utf8)
        data.append(envelope())

        #expect(try CodeSetDecoder.decode(data).release == "2026")
    }

    @Test("should retire codes missing from a replace-mode envelope")
    func replaceEnvelopeRetiresMissingCodes() async throws {
        let store = try Fixtures.store()
        try await store.ingest(CodeSetImport(codes: Fixtures.icd10))

        let codeSet = try CodeSetDecoder.decode(envelope())
        let summary = try await store.ingest(codeSet)

        #expect(summary.retired == Fixtures.icd10.count - 1)
    }
}
