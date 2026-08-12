import CodeBarUI
import CodeCore
import CodeLibrary
import CodePlatform
import SwiftUI

@main
struct CodeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // The window is for what does not fit in two seconds: seeing where a
        // code sits, what is beneath it, and what the publisher says about
        // coding it. The panel stays the fast path. See ARCHITECTURE.md §11.
        WindowGroup("CodeBar", id: BrowseWindow.id) {
            MainWindowView(
                model: BrowseViewModel(
                    repository: appDelegate.environment.repository,
                    library: appDelegate.environment.library,
                    preferences: SearchPanelController.shared.preferences
                ),
                isPinned: { appDelegate.actions.isPinned($0) },
                onCopy: { code, format in appDelegate.actions.copy(code, format: format) },
                onTogglePin: { appDelegate.actions.togglePin($0) }
            )
            .frame(minWidth: 900, minHeight: 560)
            .task { await appDelegate.actions.refresh() }
        }
        .defaultSize(width: 1080, height: 680)
        .commands {
            // The app menu's stock About item shows name, version and copyright
            // and nothing else. CodeBar's own also lists the installed code sets
            // and their releases, which is the only place to answer "which
            // release am I on?" — and a stale code set is invisible until someone
            // copies a retired code from it.
            //
            // This menu did not exist while the app launched as an accessory, so
            // the menu bar item was the only way in and the stock item was never
            // reachable to be replaced.
            CommandGroup(replacing: .appInfo) {
                Button("About CodeBar") {
                    AboutPanel.present(repository: appDelegate.environment.repository)
                }
            }

            CommandGroup(after: .newItem) {
                Button("Open Search  \(KeyCombo.default.displayString)") {
                    SearchPanelController.shared.show()
                }
            }
        }

        MenuBarExtra("CodeBar", systemImage: "stethoscope") {
            Button("Open Search  (\(KeyCombo.default.displayString))") {
                SearchPanelController.shared.show()
            }
            Button("Browse Codes…") {
                showBrowseWindow()
            }
            Divider()

            Button("Import Code Set…") {
                CodeImporter.presentImportPanel(repository: appDelegate.environment.repository)
            }
            SettingsLink { Text("Settings…") }
                .keyboardShortcut(",", modifiers: .command)

            Divider()
            Button("About CodeBar") {
                AboutPanel.present(repository: appDelegate.environment.repository)
            }
            Button("Quit CodeBar") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)

        // The app's first real window. docs/ARCHITECTURE.md §11 — CodeBar is
        // growing into a full app that keeps the menu bar panel, and later panes
        // plug in here.
        Settings {
            SettingsView(
                codeSets: CodeSetsViewModel(
                    repository: appDelegate.environment.repository,
                    preferences: SearchPanelController.shared.preferences
                ),
                isOpenAtLoginEnabled: { LoginItem.isEnabled },
                setOpenAtLogin: { LoginItem.setEnabled($0) },
                isDockIconShown: { SearchPanelController.shared.preferences.showsDockIcon },
                setDockIconShown: { shows in
                    SearchPanelController.shared.preferences.showsDockIcon = shows
                    ActivationPolicyController.setShowsDockIcon(shows)
                }
            )
        }
    }
}


private extension CodeBarApp {
    /// Focus the window that exists, and only build one when none does.
    ///
    /// Calling `openWindow` unconditionally adds a window every time, so the menu
    /// item would clone the window rather than return to it.
    func showBrowseWindow() {
        if !BrowseWindow.focusExisting() {
            openWindow(id: BrowseWindow.id)
        }
    }
}
