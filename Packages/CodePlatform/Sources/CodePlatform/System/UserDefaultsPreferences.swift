import CodeCore
import Foundation

private let DISABLED_SYSTEMS_KEY = "CodeBar.disabledSystems"
private let SHOWS_DOCK_ICON_KEY = "CodeBar.showsDockIcon"

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

    public var showsDockIcon: Bool {
        get { defaults.object(forKey: SHOWS_DOCK_ICON_KEY) as? Bool ?? true }
        set { defaults.set(newValue, forKey: SHOWS_DOCK_ICON_KEY) }
    }

    public var hotkey: KeyCombo {
        get { KeyCombo.load(from: defaults) }
        set { newValue.save(to: defaults) }
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
