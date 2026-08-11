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
    let onChoose: (ClinicalCode) -> Void
    let onTogglePin: (ClinicalCode) -> Void

    @State private var listHeight: CGFloat = 0

    var body: some View {
        if pinned.isEmpty && recent.isEmpty {
            hint
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    section("Pinned", codes: pinned, isPinnedSection: true)
                    section("Recent", codes: recent, isPinnedSection: false)
                }
                .padding(.vertical, 6)
                .measuringHeight()
            }
            .frame(height: min(listHeight, RESULT_LIST_MAX_HEIGHT))
            .onPreferenceChange(ContentHeightPreferenceKey.self) { listHeight = $0 }
        }
    }

    @ViewBuilder
    private func section(_ title: String, codes: [ClinicalCode], isPinnedSection: Bool) -> some View {
        if !codes.isEmpty {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 2)

            ForEach(codes) { code in
                ResultRow(
                    code: code,
                    isSelected: false,
                    isPinned: isPinnedSection,
                    onTogglePin: { onTogglePin(code) }
                )
                .contentShape(Rectangle())
                .onTapGesture { onChoose(code) }
            }
        }
    }

    private var hint: some View {
        VStack(spacing: 4) {
            Text("Start typing a term or a code")
                .foregroundStyle(.secondary)
            Text("e.g. \"type 2 diabetes\" or \"E11\"")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
