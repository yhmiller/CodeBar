import AppKit

/// Launch and teardown hooks. `MenuBarExtra` is a `Scene`, which has no `.task`
/// modifier, so the async startup work hangs off the delegate instead.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()

    func applicationDidFinishLaunching(_ notification: Notification) {
        SearchPanelController.shared.repository = environment.repository

        HotkeyManager.shared.onTrigger = {
            SearchPanelController.shared.toggle()
        }
        HotkeyManager.shared.start()

        if let failure = environment.startupFailure {
            presentStartupFailure(failure)
            return
        }

        Task { await environment.loadSeedIfNeeded() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
    }

    private func presentStartupFailure(_ failure: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "CodeBar could not open its database"
        alert.informativeText = "Search will not work until this is resolved.\n\n\(failure)"
        alert.runModal()
    }
}
