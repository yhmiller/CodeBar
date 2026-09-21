import CodeCore
import SwiftUI

struct EmptyStateView: View {
    let pinned: [ClinicalCode]
    let recent: [ClinicalCode]
    var scopedSystem: CodeSystem? = nil

    var showsSystemBadge: Bool = true
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
            if let scopedSystem {
                Text("Search \(scopedSystem.shortLabel) codes")
                    .foregroundStyle(.secondary)
                Text("e.g. \(scopedExample(for: scopedSystem))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Start typing a term or a code")
                    .foregroundStyle(.secondary)
                Text("e.g. \"type 2 diabetes\" or \"E11\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Metric.xl)
        .frame(maxWidth: .infinity)
    }

    private func scopedExample(for system: CodeSystem) -> String {
        switch system {
        case .cpt: "\"99214\" or \"office visit\""
        case .loinc: "\"glucose\" or \"hemoglobin a1c\""
        case .icd10cm: "\"type 2 diabetes\" or \"E11.9\""
        case .snomed: "\"asthma\" or \"195967001\""
        }
    }
}
