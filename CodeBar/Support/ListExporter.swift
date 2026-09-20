import AppKit
import CodeCore
import CodePlatform
import UniformTypeIdentifiers

@MainActor
enum ListExporter {

    static func copyToClipboard(_ content: String) {
        SystemPasteboard().write(content)
    }

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
