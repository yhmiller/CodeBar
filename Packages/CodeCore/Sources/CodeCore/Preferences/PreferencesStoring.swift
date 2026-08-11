/// Settings the user controls.
///
/// Kept behind a protocol for the same reason as everything else in `CodeCore`:
/// the UI can be tested against a fake, and the persistence mechanism can change
/// without a view knowing. Today it is `UserDefaults`; §11 anticipates some of
/// this moving into a user database as features accumulate.
@MainActor
public protocol PreferencesStoring {
    /// Systems included in search. Empty means every installed system.
    var enabledSystems: Set<CodeSystem> { get }
    func setSystem(_ system: CodeSystem, enabled: Bool)

    /// Whether CodeBar appears in the Dock as a full app, rather than living
    /// only in the menu bar. Defaults to `false` while there is no main window
    /// behind the icon.
    var showsDockIcon: Bool { get set }
}
