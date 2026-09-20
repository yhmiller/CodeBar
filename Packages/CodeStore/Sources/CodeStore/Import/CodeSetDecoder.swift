import CodeCore
import Foundation

public enum CodeSetDecoder {

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
        let noteGroups: [[CodeNote]?]

        private enum CodingKeys: String, CodingKey {
            case formatVersion, system, release, mode, codes
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            formatVersion = try container.decode(Int.self, forKey: .formatVersion)
            system = try container.decodeIfPresent(CodeSystem.self, forKey: .system)
            release = try container.decodeIfPresent(String.self, forKey: .release)
            mode = try container.decodeIfPresent(CodeSetImport.Mode.self, forKey: .mode)
            codes = try container.decode([ClinicalCode].self, forKey: .codes)
            noteGroups = try container.decode([NoteCarrier].self, forKey: .codes).map(\.notes)
        }
    }

    private struct NoteCarrier: Decodable {
        let notes: [CodeNote]?
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
            return CodeSetImport(codes: try JSONDecoder().decode([ClinicalCode].self, from: data))
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.formatVersion <= supportedFormatVersion else {
            throw DecodingError.unsupportedFormatVersion(envelope.formatVersion)
        }

        if let declared = envelope.system,
           let mismatch = envelope.codes.first(where: { $0.system != declared }) {
            throw DecodingError.systemMismatch(declared: declared, found: mismatch.system)
        }

        var notes: [String: [CodeNote]] = [:]
        for (code, group) in zip(envelope.codes, envelope.noteGroups) {
            if let group, !group.isEmpty { notes[code.id] = group }
        }

        return CodeSetImport(
            codes: envelope.codes,
            notes: notes,
            release: envelope.release,
            mode: envelope.mode ?? .merge
        )
    }

    private static func isEnvelope(_ data: Data) -> Bool {
        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        return data.first { !whitespace.contains($0) } == UInt8(ascii: "{")
    }
}
