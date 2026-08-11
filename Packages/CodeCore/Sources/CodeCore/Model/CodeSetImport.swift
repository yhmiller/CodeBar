/// A batch of codes to load into the store.
public struct CodeSetImport: Sendable, Equatable {

    /// How an incoming batch interacts with what is already installed.
    public enum Mode: String, Codable, Sendable {
        /// Add and update, leave everything else alone. What the app did before
        /// this format existed, and the safe default for a partial batch.
        case merge
        /// Treat the batch as the complete contents of each system it covers:
        /// codes absent from the batch are deleted.
        ///
        /// This is the mode a yearly release should use. Merging a new release
        /// leaves codes retired by the publisher permanently searchable, and a
        /// retired code copied into a chart is a denial.
        case replace
    }

    public let codes: [ClinicalCode]
    public let release: String?
    public let mode: Mode

    public init(codes: [ClinicalCode], release: String? = nil, mode: Mode = .merge) {
        self.codes = codes
        self.release = release
        self.mode = mode
    }

    /// Distinct systems covered by this batch.
    public var systems: Set<CodeSystem> {
        Set(codes.map(\.system))
    }
}

/// What an import actually did, in terms a user can act on.
///
/// Counts are net effects on what is installed, not internal operations. A
/// replace import deletes the old set and writes the new one, but reporting that
/// raw delete would tell someone 100 codes were retired when 8 of them came
/// straight back. `added` and `retired` are therefore both non-negative and at
/// most one of them is non-zero.
public struct IngestSummary: Sendable, Equatable {
    /// Rows read from the file.
    public let processed: Int
    /// Codes installed for the affected systems once the import finished.
    public let installed: Int
    /// Net increase. Zero when the set shrank or stayed the same.
    public let added: Int
    /// Net decrease. Zero when the set grew or stayed the same.
    public let retired: Int
    public let systems: Set<CodeSystem>

    public init(processed: Int, installedBefore: Int, installedAfter: Int, systems: Set<CodeSystem>) {
        self.processed = processed
        self.installed = installedAfter
        self.added = max(0, installedAfter - installedBefore)
        self.retired = max(0, installedBefore - installedAfter)
        self.systems = systems
    }

    /// True when the import left the installed set exactly as it found it.
    public var isUnchanged: Bool {
        added == 0 && retired == 0
    }
}
