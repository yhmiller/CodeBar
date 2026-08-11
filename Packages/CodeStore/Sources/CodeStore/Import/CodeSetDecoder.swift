import CodeCore
import Foundation

/// Reads a code-set JSON file into a `CodeSetImport`.
///
/// Currently handles the bare-array format emitted by `Scripts/import_*.py` and
/// used by the bundled seed. The versioned envelope described in
/// docs/ARCHITECTURE.md §5.5 — which carries the release stamp and replace
/// semantics — lands in phase 7; `CodeSetImport` already models both.
public enum CodeSetDecoder {

    public static func decode(
        _ data: Data,
        release: String? = nil,
        mode: CodeSetImport.Mode = .merge
    ) throws -> CodeSetImport {
        let codes = try JSONDecoder().decode([ClinicalCode].self, from: data)
        return CodeSetImport(codes: codes, release: release, mode: mode)
    }

    public static func decode(
        contentsOf url: URL,
        release: String? = nil,
        mode: CodeSetImport.Mode = .merge
    ) throws -> CodeSetImport {
        try decode(Data(contentsOf: url), release: release, mode: mode)
    }
}
