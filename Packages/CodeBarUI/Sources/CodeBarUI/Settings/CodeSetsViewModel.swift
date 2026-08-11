import CodeCore
import Observation

/// Backs the Code Sets settings pane.
///
/// The installed release matters clinically: a code set a year out of date still
/// answers every query confidently, and the only visible symptom is a code the
/// publisher has since retired. Surfacing release and row count is what makes
/// that checkable rather than assumed.
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

    /// Removes an installed code set. Destructive, so the caller confirms first.
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

    /// Bumped so SwiftUI re-reads values that live in the preferences store
    /// rather than in observed properties here.
    public private(set) var preferenceRevision = 0
}
