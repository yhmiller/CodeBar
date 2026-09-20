import SwiftUI

struct PanelFooter: View {
    enum Context {
        case results
        case suggestions
    }

    let context: Context

    var body: some View {
        HStack(spacing: Metric.l) {
            ForEach(shortcuts, id: \.key) { shortcut in
                item(shortcut)
            }
            Spacer(minLength: Metric.s)
        }
        .padding(.horizontal, Metric.l)
        .padding(.vertical, Metric.s)
        .background(.bar)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
    }

    private struct Shortcut {
        let key: String
        let label: String
    }

    private var shortcuts: [Shortcut] {
        switch context {
        case .results:
            [Shortcut(key: "↵", label: "Copy"),
             Shortcut(key: "⇧↵", label: "With description"),
             Shortcut(key: "⌘1–9", label: "Copy nth"),
             Shortcut(key: "⌘P", label: "Pin")]
        case .suggestions:
            [Shortcut(key: "↵", label: "Copy"),
             Shortcut(key: "⌘P", label: "Pin")]
        }
    }

    private func item(_ shortcut: Shortcut) -> some View {
        HStack(spacing: Metric.xs) {
            Text(shortcut.key)
                .font(CodeTypography.metadata.monospaced())
                .padding(.horizontal, Metric.xs)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: Metric.chipRadius))
            Text(shortcut.label)
                .font(CodeTypography.metadata)
                .foregroundStyle(.secondary)
        }
    }

    private var spokenSummary: String {
        let spoken = shortcuts.map { "\($0.key) \($0.label)" }.joined(separator: ", ")
        return "Shortcuts: \(spoken)"
    }
}
