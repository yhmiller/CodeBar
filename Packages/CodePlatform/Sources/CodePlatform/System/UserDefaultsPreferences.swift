import CodeCore
import Foundation

private let DISABLED_SYSTEMS_KEY = "CodeBar.disabledSystems"
private let SHOWS_DOCK_ICON_KEY = "CodeBar.showsDockIcon"

/// Preferences backed by `UserDefaults`.
///
/// Stores which systems are *disabled* rather than which are enabled, so a code
/// system added in a future release is searchable by default instead of being
/// silently excluded because it was missing from a stored allow-list.
@MainActor
public final class UserDefaultsPreferences: PreferencesStoring {
    private let defaults: UserDefaults
    private var disabledSystems: Set<CodeSystem>

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: DISABLED_SYSTEMS_KEY) ?? []
        disabledSystems = Set(stored.compactMap(CodeSystem.init(rawValue:)))
    }

    public var enabledSystems: Set<CodeSystem> {
        Set(CodeSystem.allCases).subtracting(disabledSystems)
    }

    public func isEnabled(_ system: CodeSystem) -> Bool {
        !disabledSystems.contains(system)
    }

    /// Defaults to false: a Dock icon that opens nothing is worse than none.
    /// Flips to true in phase 8.4, when there is a window behind it.
    public var showsDockIcon: Bool {
        get { defaults.bool(forKey: SHOWS_DOCK_ICON_KEY) }
        set { defaults.set(newValue, forKey: SHOWS_DOCK_ICON_KEY) }
    }

    public func setSystem(_ system: CodeSystem, enabled: Bool) {
        if enabled {
            disabledSystems.remove(system)
        } else {
            disabledSystems.insert(system)
        }
        defaults.set(disabledSystems.map(\.rawValue).sorted(), forKey: DISABLED_SYSTEMS_KEY)
    }
}
