import AppKit
import CodeBarUI
import CodeCore
import CodePlatform

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let environment = AppEnvironment()

    lazy var actions = LibraryActions(
        library: environment.library ?? EmptyCodeLibrary(),
        repository: environment.repository
    )

    lazy var browseModel = BrowseViewModel(
        repository: environment.repository,
        library: environment.library,
        preferences: SearchPanelController.shared.preferences
    )

    @Published public private(set) var currentHotkey: KeyCombo = .default

    func handoffToBrowseWindow(_ code: ClinicalCode) {
        BrowseWindow.show(code: code)
    }

    private let hotkeyRegistrar = CarbonHotkeyRegistrar()

    func applicationDidFinishLaunching(_ notification: Notification) {
        SearchPanelController.shared.repository = environment.repository
        SearchPanelController.shared.library = environment.library

        ActivationPolicyController.setShowsDockIcon(
            SearchPanelController.shared.preferences.showsDockIcon
        )
        currentHotkey = SearchPanelController.shared.preferences.hotkey
        registerHotkey(currentHotkey)

        if let failure = environment.startupFailure {
            presentAlert(
                style: .critical,
                title: "CodeBar could not open its database",
                message: "Search will not work until this is resolved.\n\n\(failure)"
            )
            return
        }

        Task {
            await environment.adoptLegacyLibraryData()
            await environment.loadSeedIfNeeded()
            await actions.refresh()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyRegistrar.unregister()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        !BrowseWindow.focusExisting()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @discardableResult
    func updateHotkey(keyCode: UInt32, carbonModifiers: UInt32) -> Result<Void, HotkeyRecordingError> {
        let candidate = KeyCombo(keyCode: keyCode, carbonModifiers: carbonModifiers)
        guard candidate.isValidHotkey else {
            return .failure(HotkeyRecordingError("Include ⌘, ⌥, or ⌃"))
        }

        let previous = currentHotkey
        do {
            try hotkeyRegistrar.register(candidate) {
                SearchPanelController.shared.toggle()
            }
            SearchPanelController.shared.preferences.hotkey = candidate
            currentHotkey = candidate
            return .success(())
        } catch {
            try? hotkeyRegistrar.register(previous) {
                SearchPanelController.shared.toggle()
            }
            return .failure(HotkeyRecordingError("Shortcut already in use"))
        }
    }

    func resetHotkey() {
        _ = updateHotkey(keyCode: KeyCombo.default.keyCode, carbonModifiers: KeyCombo.default.carbonModifiers)
    }

    private func registerHotkey(_ combo: KeyCombo) {
        do {
            try hotkeyRegistrar.register(combo) {
                SearchPanelController.shared.toggle()
            }
        } catch {
            presentAlert(
                style: .warning,
                title: "The \(combo.displayString) shortcut is unavailable",
                message: "\(error)\n\nCodeBar still works from the menu bar icon."
            )
        }
    }

    private func presentAlert(style: NSAlert.Style, title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
