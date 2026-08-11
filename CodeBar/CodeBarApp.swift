import SwiftUI

@main
struct CodeBarApp: App {

    init() {
        CodeDatabase.shared.loadSeedDataIfNeeded()
        HotkeyManager.shared.onTrigger = {
            SearchPanelController.shared.toggle()
        }
        HotkeyManager.shared.start()
    }

    var body: some Scene {
        MenuBarExtra("CodeBar", systemImage: "stethoscope") {
            Button("Open Search  (⌥⌘C)") {
                SearchPanelController.shared.show()
            }
            Divider()
            Button("Import Code Set…") {
                CodeImporter.presentImportPanel()
            }
            Divider()
            Button("Quit CodeBar") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
