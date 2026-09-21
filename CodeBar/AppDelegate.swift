import AppKit
import CodePlatform

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()

    lazy var actions = LibraryActions(
        library: environment.library ?? EmptyCodeLibrary(),
        repository: environment.repository
    )

    private let hotkeyRegistrar = CarbonHotkeyRegistrar()

    func applicationDidFinishLaunching(_ notification: Notification) {
        SearchPanelController.shared.repository = environment.repository
        SearchPanelController.shared.library = environment.library

        ActivationPolicyController.setShowsDockIcon(
            SearchPanelController.shared.preferences.showsDockIcon
        )
        registerHotkey()

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

    private func registerHotkey() {
        do {
            try hotkeyRegistrar.register(.default) {
                SearchPanelController.shared.toggle()
            }
        } catch {
            presentAlert(
                style: .warning,
                title: "The \(KeyCombo.default.displayString) shortcut is unavailable",
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
