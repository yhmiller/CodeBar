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
}
