import CodeCore
import Observation

@MainActor
@Observable
public final class CodeSetsViewModel {

    public private(set) var manifests: [CodeSetManifest] = []
    public private(set) var isWorking = false
    public private(set) var failure: String?

    private let repository: (any CodeRepository)?
    private let preferences: any PreferencesStoring

    public init(repository: (any CodeRepository)?, preferences: any PreferencesStoring) {
        self.repository = repository
        self.preferences = preferences
    }

    public func load() async {
        guard let repository else {
            failure = "CodeBar could not open its database."
            return
        }
        do {
            manifests = try await repository.manifests()
            failure = nil
        } catch {
            failure = String(describing: error)
        }
    }

    public func remove(_ system: CodeSystem) async {
        guard let repository else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await repository.removeCodeSet(system)
            await load()
        } catch {
            failure = String(describing: error)
        }
    }

    // MARK: - Per-system search filtering

    public func isSearchEnabled(_ system: CodeSystem) -> Bool {
        preferences.enabledSystems.contains(system)
    }

    public func setSearchEnabled(_ system: CodeSystem, _ enabled: Bool) {
        preferences.setSystem(system, enabled: enabled)
        preferenceRevision += 1
    }

    public private(set) var preferenceRevision = 0
}
