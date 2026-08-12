import AppKit
import CodePlatform

/// Launch and teardown hooks. `MenuBarExtra` is a `Scene`, which has no `.task`
/// modifier, so the async startup work hangs off the delegate instead.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()

    /// Shared by the panel and the window, so a pin made in one shows in the other.
    lazy var actions = LibraryActions(library: environment.library ?? EmptyCodeLibrary())

    private let hotkeyRegistrar = CarbonHotkeyRegistrar()

    func applicationDidFinishLaunching(_ notification: Notification) {
        SearchPanelController.shared.repository = environment.repository
        SearchPanelController.shared.library = environment.library

        // The app launches as a normal app so that opening it opens its window.
        // Anyone who wants menu-bar-only gets demoted here instead; the cost is a
        // brief Dock icon at launch for them, which is the better trade now that
        // the window is the primary surface rather than an afterthought.
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
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyRegistrar.unregister()
    }

    /// Opening the app means the window, never the panel.
    ///
    /// The two surfaces are reached deliberately differently: ⌥⌘C and the menu
    /// bar summon the panel, which copies a code and gets out of the way; the
    /// Dock icon and the app itself open the window. Until 8.4 there was no
    /// window, so this opened the panel — which is why launching the app used to
    /// throw a search field at you.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows else { return true }

        if let window = mainWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return true
        }

        // No window built yet. Returning false hands back to AppKit's default,
        // which asks SwiftUI to create one from the WindowGroup.
        return false
    }

    /// The browse window, as distinct from the floating search panel.
    private var mainWindow: NSWindow? {
        NSApp.windows.first { $0.canBecomeMain && !($0 is NSPanel) }
    }

    /// Closing the window leaves CodeBar in the menu bar, still on ⌥⌘C.
    ///
    /// AppKit already defaults to this, but stating it is cheap and the default
    /// is easy to lose to a stray Info.plist key. The failure it prevents — the
    /// shortcut silently doing nothing because the app quietly quit — is the one
    /// this app can least afford.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
