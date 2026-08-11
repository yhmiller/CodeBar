import AppKit
import UniformTypeIdentifiers

/// Handles "Import Code Set…" from the menu bar menu: pick a JSON file
/// (produced by one of the Scripts/import_*.py converters) and load it
/// into the search database.
enum CodeImporter {
    static func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import Code Set (JSON)"
        panel.message = "Choose a JSON file produced by one of the Scripts/import_*.py converters."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let codes = try JSONDecoder().decode([ClinicalCode].self, from: data)
            CodeDatabase.shared.importCodes(codes)

            let alert = NSAlert()
            alert.messageText = "Import complete"
            alert.informativeText = "Added \(codes.count) codes."
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Import failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
