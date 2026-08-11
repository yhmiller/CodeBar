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
            Divider()
            Button("Quit CodeBar") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
