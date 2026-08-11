import Foundation

/// What the store knows about one installed code set.
///
/// The release stamp is the reason this exists: without it there is no way to
/// tell whether the installed ICD-10-CM set is the current year's, and a
/// silently stale set is a clinical hazard, not just a staleness annoyance.
public struct CodeSetManifest: Identifiable, Hashable, Sendable {
    public var id: CodeSystem { system }

    public let system: CodeSystem
    /// Publisher's release identifier, e.g. `2026`. `nil` for the bundled seed
    /// and for imports that predate the versioned format.
    public let release: String?
    public let importedAt: Date
    public let rowCount: Int

    public init(system: CodeSystem, release: String?, importedAt: Date, rowCount: Int) {
        self.system = system
        self.release = release
        self.importedAt = importedAt
        self.rowCount = rowCount
    }
}
