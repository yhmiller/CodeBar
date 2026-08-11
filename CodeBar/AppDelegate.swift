import AppKit
import CodePlatform

/// Launch and teardown hooks. `MenuBarExtra` is a `Scene`, which has no `.task`
/// modifier, so the async startup work hangs off the delegate instead.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()

    private let hotkeyRegistrar = CarbonHotkeyRegistrar()

    func applicationDidFinishLaunching(_ notification: Notification) {
        SearchPanelController.shared.repository = environment.repository
        SearchPanelController.shared.library = environment.library
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
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyRegistrar.unregister()
    }

    /// A failed registration is reported rather than swallowed. The previous
    /// implementation could not fail visibly — without Accessibility permission
    /// the event monitor simply never fired, so the shortcut appeared to be
    /// broken with nothing to explain why.
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
