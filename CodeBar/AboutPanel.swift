import AppKit
import CodeCore

private let TAGLINE = "Fast clinical code lookup for ICD-10-CM, LOINC, SNOMED CT and CPT."
private let WEBSITE = URL(string: "https://www.princemiller.com")!
private let WEBSITE_LABEL = "www.princemiller.com"

@MainActor
enum AboutPanel {

    static func present(repository: (any CodeRepository)?) {
        Task {
            let manifests = (try? await repository?.manifests()) ?? []
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(options: [.credits: credits(for: manifests)])
        }
    }

    private static func credits(for manifests: [CodeSetManifest]) -> NSAttributedString {
        let credits = NSMutableAttributedString()

        let centred = NSMutableParagraphStyle()
        centred.alignment = .center
        centred.paragraphSpacing = 6

        credits.append(NSAttributedString(
            string: TAGLINE + "\n\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: centred
            ]
        ))

        credits.append(NSAttributedString(
            string: installedSummary(manifests) + "\n\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: centred
            ]
        ))

        credits.append(NSAttributedString(
            string: WEBSITE_LABEL,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .link: WEBSITE,
                .paragraphStyle: centred
            ]
        ))

        return credits
    }

    private static func installedSummary(_ manifests: [CodeSetManifest]) -> String {
        guard !manifests.isEmpty else { return "No code sets installed." }

        return manifests
            .sorted { $0.system.rawValue < $1.system.rawValue }
            .map { manifest in
                let count = manifest.rowCount.formatted(.number.grouping(.automatic))
                guard let release = manifest.release else {
                    return "\(manifest.system.rawValue) — \(count) codes"
                }
                return "\(manifest.system.rawValue) release \(release) — \(count) codes"
            }
            .joined(separator: "\n")
    }
}
