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

/// What an import actually did.
public struct IngestSummary: Sendable, Equatable {
    /// Rows read from the batch.
    public let processed: Int
    /// Net change in stored row count. Re-importing an identical set gives `0`.
    public let netAdded: Int
    /// Rows deleted by `.replace` mode.
    public let removed: Int
    public let systems: Set<CodeSystem>

    public init(processed: Int, netAdded: Int, removed: Int, systems: Set<CodeSystem>) {
        self.processed = processed
        self.netAdded = netAdded
        self.removed = removed
        self.systems = systems
    }
}
