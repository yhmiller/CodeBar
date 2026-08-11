import CodeBarUI
import CodePlatform
import SwiftUI

@main
struct CodeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("CodeBar", systemImage: "stethoscope") {
            Button("Open Search  (\(KeyCombo.default.displayString))") {
                SearchPanelController.shared.show()
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
