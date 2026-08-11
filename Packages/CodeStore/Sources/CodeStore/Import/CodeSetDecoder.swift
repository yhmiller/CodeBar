import CodeCore
import Foundation

/// Reads a code-set file into a `CodeSetImport`.
///
/// Two shapes are accepted. The current one is a versioned envelope carrying the
/// publisher's release and how the batch should be applied:
///
/// ```json
/// { "formatVersion": 1, "system": "ICD-10-CM", "release": "2026",
///   "mode": "replace", "codes": [ … ] }
/// ```
///
/// The other is a bare array of codes, which is what earlier converter scripts
/// emitted. Those files are still readable; they simply cannot express a release
/// or ask for replace semantics, so they merge.
public enum CodeSetDecoder {

    /// Envelope revisions this build understands.
    public static let supportedFormatVersion = 1

    public enum DecodingError: Error, CustomStringConvertible, Equatable {
        case unsupportedFormatVersion(Int)
        case systemMismatch(declared: CodeSystem, found: CodeSystem)
        case empty

        public var description: String {
            switch self {
            case .unsupportedFormatVersion(let version):
                "This file uses code-set format version \(version); this build of "
                    + "CodeBar understands version \(supportedFormatVersion)."
            case .systemMismatch(let declared, let found):
                "The file says it contains \(declared.rawValue) codes but includes "
                    + "\(found.rawValue) codes."
            case .empty:
                "The file contains no codes."
            }
        }
    }

    private struct Envelope: Decodable {
        let formatVersion: Int
        let system: CodeSystem?
        let release: String?
        let mode: CodeSetImport.Mode?
        let codes: [ClinicalCode]
    }

    public static func decode(_ data: Data) throws -> CodeSetImport {
        let codeSet = try decodeShape(data)
        guard !codeSet.codes.isEmpty else { throw DecodingError.empty }
        return codeSet
    }

    public static func decode(contentsOf url: URL) throws -> CodeSetImport {
        try decode(Data(contentsOf: url))
    }

    private static func decodeShape(_ data: Data) throws -> CodeSetImport {
        guard isEnvelope(data) else {
            // Legacy bare array: no release, and merge is the only safe default
            // since the file cannot say whether it is a complete set.
            return CodeSetImport(codes: try JSONDecoder().decode([ClinicalCode].self, from: data))
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.formatVersion <= supportedFormatVersion else {
            throw DecodingError.unsupportedFormatVersion(envelope.formatVersion)
        }

        // A mislabelled file could delete the wrong system's codes under replace
        // mode, so the declared system is checked rather than trusted.
        if let declared = envelope.system,
           let mismatch = envelope.codes.first(where: { $0.system != declared }) {
            throw DecodingError.systemMismatch(declared: declared, found: mismatch.system)
        }

        return CodeSetImport(
            codes: envelope.codes,
            release: envelope.release,
            mode: envelope.mode ?? .merge
        )
    }

    /// Distinguishes `{ … }` from `[ … ]` without parsing the whole document.
    private static func isEnvelope(_ data: Data) -> Bool {
        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        return data.first { !whitespace.contains($0) } == UInt8(ascii: "{")
    }
}
