public struct CodeSetImport: Sendable, Equatable {

    public enum Mode: String, Codable, Sendable {
        case merge
        case replace
    }

    public let codes: [ClinicalCode]
    public let notes: [String: [CodeNote]]
    public let release: String?
    public let mode: Mode

    public init(
        codes: [ClinicalCode],
        notes: [String: [CodeNote]] = [:],
        release: String? = nil,
        mode: Mode = .merge
    ) {
        self.codes = codes
        self.notes = notes
        self.release = release
        self.mode = mode
    }

    public var systems: Set<CodeSystem> {
        Set(codes.map(\.system))
    }
}

public struct IngestSummary: Sendable, Equatable {
    public let processed: Int
    public let installed: Int
    public let added: Int
    public let retired: Int
    public let systems: Set<CodeSystem>

    public init(processed: Int, installedBefore: Int, installedAfter: Int, systems: Set<CodeSystem>) {
        self.processed = processed
        self.installed = installedAfter
        self.added = max(0, installedAfter - installedBefore)
        self.retired = max(0, installedBefore - installedAfter)
        self.systems = systems
    }

    public var isUnchanged: Bool {
        added == 0 && retired == 0
    }
}
