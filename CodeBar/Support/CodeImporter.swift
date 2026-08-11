import AppKit
import CodeCore
import CodeStore
import UniformTypeIdentifiers

/// Handles "Import Code Set…": pick a JSON file produced by one of the
/// `Scripts/import_*.py` converters and load it into the search index.
enum CodeImporter {

    @MainActor
    static func presentImportPanel(repository: (any CodeRepository)?) {
        guard let repository else {
            presentAlert(style: .critical, title: "Import unavailable",
                         message: "CodeBar could not open its database.")
            return
        }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import Code Set (JSON)"
        panel.message = "Choose a JSON file produced by one of the Scripts/import_*.py converters."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            do {
                let summary = try await repository.ingest(CodeSetDecoder.decode(contentsOf: url))
                presentAlert(style: .informational, title: "Import complete",
                             message: describe(summary))
            } catch {
                presentAlert(style: .warning, title: "Import failed",
                             message: String(describing: error))
            }
        }
    }

    /// Reports the net change rather than the file's row count, so re-importing
    /// a file the user already has reads as "nothing new" instead of implying
    /// the codes were added a second time.
    private static func describe(_ summary: IngestSummary) -> String {
        let systems = summary.systems
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")

        switch summary.netAdded {
        case 0:
            return "Read \(summary.processed) codes from \(systems). Nothing new — your copy was already up to date."
        default:
            return "Read \(summary.processed) codes from \(systems). Added \(summary.netAdded) new codes."
        }
    }

    @MainActor
    private static func presentAlert(style: NSAlert.Style, title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
