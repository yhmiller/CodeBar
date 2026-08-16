import AppKit
import CodeCore
import CodePlatform
import UniformTypeIdentifiers

/// Gets a saved list out of CodeBar: onto the clipboard, or into a file.
///
/// A curated list that can only be read inside the app that holds it is worth
/// much less than one that can be pasted into a note or opened in a spreadsheet.
@MainActor
enum ListExporter {

    static func copyToClipboard(_ content: String) {
        SystemPasteboard().write(content)
    }

    /// Asks where to put it, then writes it.
    ///
    /// Writing needs `files.user-selected.read-write` in the entitlements. The
    /// read-only variant is enough to *choose* a file and would fail at the
    /// write, which is the worst place to find out.
    static func save(_ content: String, as format: ListExportFormat, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .csv ? .commaSeparatedText : .plainText]
        panel.nameFieldStringValue = "\(sanitised(suggestedName)).\(format.fileExtension)"
        panel.title = "Export List"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            presentAlert(
                title: "CodeBar could not write that file",
                message: "\(error.localizedDescription)"
            )
        }
    }

    /// A list is named by the user, so it can hold anything a text field allows.
    /// `/` and `:` are the two that a file name cannot.
    private static func sanitised(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "Codes" : cleaned
    }

    private static func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
