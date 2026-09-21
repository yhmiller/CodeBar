import SwiftUI

struct PanelFooter: View {
    enum Context {
        case results
        case suggestions
    }

    let context: Context
    var isPeeking: Bool = false
    var showsPeek: Bool = false

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
        var items: [Shortcut]
        switch context {
        case .results:
            items = [
                Shortcut(key: "↵", label: "Copy"),
                Shortcut(key: "⇧↵", label: "With description"),
                Shortcut(key: "⌘↵", label: "Open"),
                Shortcut(key: "⌘1–9", label: "Copy nth"),
                Shortcut(key: "⌘P", label: "Pin")
            ]
        case .suggestions:
            items = [
                Shortcut(key: "↵", label: "Copy"),
                Shortcut(key: "⌘↵", label: "Open"),
                Shortcut(key: "⌘P", label: "Pin")
            ]
        }
        if showsPeek {
            items.append(Shortcut(key: "Space", label: isPeeking ? "Close peek" : "Peek"))
        }
        return items
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
