import CodeCore
import SwiftUI

/// What the panel shows before anything is typed.
///
/// Pins and recents earn their place here beyond convenience: relevance ranking
/// cannot tell that E11.9 is the diabetes code someone uses daily, so the codes
/// they have actually reached for are the fastest correct answer available.
struct EmptyStateView: View {
    let pinned: [ClinicalCode]
    let recent: [ClinicalCode]

    /// Threaded through rather than decided here, so the empty state and the
    /// results list can never disagree about whether a row names its system.
    var showsSystemBadge: Bool = true

    /// Which suggestion the arrow keys are on, so ⌥⌘C then Return reaches a
    /// pinned code without typing — the thing the README has always promised.
    var isSelected: (ClinicalCode) -> Bool = { _ in false }

    let onChoose: (ClinicalCode) -> Void
    let onTogglePin: (ClinicalCode) -> Void

    @State private var listHeight: CGFloat = 0

    var body: some View {
        if pinned.isEmpty && recent.isEmpty {
            hint
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Metric.xxs) {
                    section("Pinned", codes: pinned, isPinnedSection: true)
                    section("Recent", codes: recent, isPinnedSection: false)
                }
                .padding(.vertical, Metric.s)
                .measuringHeight()
            }
            .frame(height: min(listHeight, Metric.resultListMaxHeight))
            .onPreferenceChange(ContentHeightPreferenceKey.self) { listHeight = $0 }
        }
    }

    @ViewBuilder
    private func section(_ title: String, codes: [ClinicalCode], isPinnedSection: Bool) -> some View {
        if !codes.isEmpty {
            // Aligned to `rowLeading`, not to a number that happens to match:
            // the header sits above rows whose text starts at the row's own
            // inset plus its padding, and the two have to move together.
            Text(title.uppercased())
                .font(CodeTypography.sectionLabel)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Metric.rowLeading)
                .padding(.top, Metric.s)
                .padding(.bottom, Metric.xxs)

            ForEach(codes) { code in
                CodeRow(
                    code: code,
                    density: .panel,
                    isSelected: isSelected(code),
                    isPinned: isPinnedSection,
                    showsSystemBadge: showsSystemBadge,
                    onTogglePin: { onTogglePin(code) }
                )
                .onTapGesture { onChoose(code) }
                .accessibilityHint("Press Return to copy")
            }
        }
    }

    private var hint: some View {
        VStack(spacing: Metric.xs) {
            Text("Start typing a term or a code")
                .foregroundStyle(.secondary)
            Text("e.g. \"type 2 diabetes\" or \"E11\"")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(Metric.xl)
        .frame(maxWidth: .infinity)
    }
}
