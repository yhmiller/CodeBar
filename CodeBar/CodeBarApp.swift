import CodePlatform
import SwiftUI

@main
struct CodeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var opensAtLogin = LoginItem.isEnabled

    var body: some Scene {
        MenuBarExtra("CodeBar", systemImage: "stethoscope") {
            Button("Open Search  (\(KeyCombo.default.displayString))") {
                SearchPanelController.shared.show()
            }
            Divider()

            Button("Import Code Set…") {
                CodeImporter.presentImportPanel(repository: appDelegate.environment.repository)
            }
            Toggle("Open at Login", isOn: $opensAtLogin)
                .onChange(of: opensAtLogin) { _, enabled in
                    guard LoginItem.setEnabled(enabled) else {
                        // Revert the tick if macOS refused, rather than showing
                        // a state the system does not actually have.
                        opensAtLogin = LoginItem.isEnabled
                        return
                    }
                }

            Divider()
            Button("About CodeBar") {
                AboutPanel.present(repository: appDelegate.environment.repository)
            }
            Button("Quit CodeBar") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
