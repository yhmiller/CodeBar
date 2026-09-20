import Foundation

public struct CodeSetManifest: Identifiable, Hashable, Sendable {
    public var id: CodeSystem { system }

    public let system: CodeSystem
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
