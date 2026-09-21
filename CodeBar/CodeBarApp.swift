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
        WindowGroup("CodeBar", id: BrowseWindow.id) {
            MainWindowView(
                model: BrowseViewModel(
                    repository: appDelegate.environment.repository,
                    library: appDelegate.environment.library,
                    preferences: SearchPanelController.shared.preferences
                ),
                isPinned: { appDelegate.actions.isPinned($0) },
                onCopy: { code, format in appDelegate.actions.copy(code, format: format) },
                onTogglePin: { appDelegate.actions.togglePin($0) },
                onExportList: { content, list, format, toFile in
                    if toFile {
                        ListExporter.save(content, as: format, suggestedName: list.name)
                    } else {
                        ListExporter.copyToClipboard(content)
                    }
                }
            )
            .frame(minWidth: 900, minHeight: 560)
            .task { await appDelegate.actions.refresh() }
        }
        .defaultSize(width: 1080, height: 680)
        .commands {
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

        Settings {
            SettingsView(
                codeSets: CodeSetsViewModel(
                    repository: appDelegate.environment.repository,
                    preferences: SearchPanelController.shared.preferences
                ),
                abbreviations: AbbreviationsViewModel(
                    library: appDelegate.environment.library
                ),
                isOpenAtLoginEnabled: { LoginItem.isEnabled },
                setOpenAtLogin: { LoginItem.setEnabled($0) },
                isDockIconShown: { SearchPanelController.shared.preferences.showsDockIcon },
                setDockIconShown: { shows in
                    SearchPanelController.shared.preferences.showsDockIcon = shows
                    ActivationPolicyController.setShowsDockIcon(shows)
                },
                onImportCodeSet: {
                    CodeImporter.presentImportPanel(repository: appDelegate.environment.repository)
                }
            )
        }
    }
}


private extension CodeBarApp {
    func showBrowseWindow() {
        if !BrowseWindow.focusExisting() {
            openWindow(id: BrowseWindow.id)
        }
    }
}
