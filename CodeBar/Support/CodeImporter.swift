import AppKit
import CodeCore
import CodeStore
import UniformTypeIdentifiers

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

        Task { await performImport(of: url, into: repository) }
    }

    @MainActor
    private static func performImport(of url: URL, into repository: any CodeRepository) async {
        do {
            let codeSet = try CodeSetDecoder.decode(contentsOf: url)

            if codeSet.mode == .replace {
                let installed = try await repository.manifests()
                guard confirmReplacement(of: codeSet, replacing: installed) else { return }
            }

            let summary = try await repository.ingest(codeSet)
            await (NSApp.delegate as? AppDelegate)?.actions.refresh()
            presentAlert(style: .informational, title: "Import complete",
                         message: describe(summary, release: codeSet.release))
        } catch {
            presentAlert(style: .warning, title: "Import failed",
                         message: String(describing: error))
        }
    }

    @MainActor
    private static func confirmReplacement(
        of codeSet: CodeSetImport,
        replacing installed: [CodeSetManifest]
    ) -> Bool {
        let affected = installed.filter { codeSet.systems.contains($0.system) }
        let existingCount = affected.reduce(0) { $0 + $1.rowCount }

        guard existingCount > 0 else { return true }

        let systems = codeSet.systems.map(\.rawValue).sorted().joined(separator: ", ")
        let incomingRelease = codeSet.release.map { " (release \($0))" } ?? ""

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Replace the installed \(systems) code set?"
        alert.informativeText = """
        This file asks to replace \(systems) rather than merge into it\(incomingRelease).

        Installed now: \(existingCount) codes
        In this file:  \(codeSet.codes.count) codes

        Any code missing from this file will be removed and will stop appearing \
        in search. That is what you want for a new yearly release, since it \
        retires codes the publisher withdrew.
        """
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func describe(_ summary: IngestSummary, release: String?) -> String {
        let systems = summary.systems.map(\.rawValue).sorted().joined(separator: ", ")
        var lines = ["Read \(summary.processed) codes from \(systems)."]

        if let release {
            lines.append("Release \(release).")
        }

        if summary.isUnchanged {
            lines.append("Nothing changed — your copy was already up to date.")
        } else if summary.added > 0 {
            lines.append("Added \(summary.added) new codes.")
        } else {
            lines.append("Retired \(summary.retired) codes that are no longer in the set.")
        }

        lines.append("\(summary.installed) codes now installed.")
        return lines.joined(separator: "\n")
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
