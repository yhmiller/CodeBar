@MainActor
public protocol PreferencesStoring {
    var enabledSystems: Set<CodeSystem> { get }
    func setSystem(_ system: CodeSystem, enabled: Bool)

    var showsDockIcon: Bool { get set }
}
