import SwiftUI

/// The panel's key map, stated rather than assumed.
///
/// `↵` and `⇧↵` shipped for a long time with no way to discover them except the
/// README, and the per-row "↵ copy" hint competed with the pin for the row's
/// trailing edge while only ever describing one of the keys. Saying it once, in
/// a fixed place, is how every keyboard-first launcher teaches its own
/// shortcuts.
struct PanelFooter: View {
    /// What the keys do depends on what is on screen — there is nothing to copy
    /// before anything is typed.
    ///
    /// There is deliberately no case for the bare hint state. With no pins, no
    /// recents and nothing typed, every key here would be inert, and a footer
    /// listing keys that do nothing is worse than no footer: the panel would be
    /// teaching a shortcut that fails the first time it is tried.
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
        // One announcement of the whole map, rather than eight fragments
        // interrupting the results a VoiceOver user is actually navigating.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
    }

    private struct Shortcut {
        let key: String
        let label: String
    }

    /// Only keys that work in the state on screen. `⌘K` is absent until the
    /// action menu exists — see DESIGN_ROADMAP.md 6.1.
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
