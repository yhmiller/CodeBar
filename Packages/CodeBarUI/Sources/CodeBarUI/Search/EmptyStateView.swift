import AppKit
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
    var onSearchExample: ((String) -> Void)? = nil


    var body: some View {
        if pinned.isEmpty && recent.isEmpty {
            heroCard
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.97)), removal: .opacity))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Metric.xxs) {
                    section(
                        title: "Pinned",
                        icon: "pin.fill",
                        iconColor: .orange,
                        codes: pinned,
                        isPinnedSection: true
                    )
                    section(
                        title: "Recent",
                        icon: "clock.arrow.circlepath",
                        iconColor: .secondary,
                        codes: recent,
                        isPinnedSection: false
                    )
                }
                .padding(.vertical, Metric.s)
            }
            .frame(maxHeight: Metric.resultListMaxHeight)
        }
    }

    @ViewBuilder
    private func section(
        title: String,
        icon: String,
        iconColor: Color,
        codes: [ClinicalCode],
        isPinnedSection: Bool
    ) -> some View {
        if !codes.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title.uppercased())
                    .font(CodeTypography.sectionLabel)
                    .foregroundStyle(.secondary)

                Text("· \(codes.count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
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

    private var themeColor: Color {
        scopedSystem?.themeColor ?? .accentColor
    }

    private var heroCard: some View {
        VStack(spacing: Metric.m) {
            // Ambient squircle icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [themeColor.opacity(0.22), themeColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(themeColor.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: themeColor.opacity(0.35), radius: 8, y: 3)

                Image(systemName: scopedSystem?.iconName ?? "stethoscope")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(themeColor)
            }

            // Headings
            VStack(spacing: 4) {
                Text(heroTitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(heroSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Interactive Clickable Example Pills
            FlowLayout(spacing: 6) {
                ForEach(examples, id: \.query) { example in
                    ExampleChip(
                        term: example.query,
                        subtitle: example.label,
                        color: themeColor,
                        action: { onSearchExample?(example.query) }
                    )
                }
            }
            .padding(.horizontal, Metric.xl)
            .padding(.top, 2)
        }
        .padding(.vertical, Metric.xl)
        .frame(maxWidth: .infinity)
    }

    private var heroTitle: String {
        guard let system = scopedSystem else {
            return "Search Clinical Codes"
        }
        switch system {
        case .cpt: return "Search CPT Procedures"
        case .loinc: return "Search LOINC Laboratories"
        case .icd10cm: return "Search ICD-10 Diagnoses"
        case .snomed: return "Search SNOMED Terminology"
        }
    }

    private var heroSubtitle: String {
        guard scopedSystem != nil else {
            return "Type clinical descriptions, codes, or explore shortcuts:"
        }
        return "Click an example below or type to search:"
    }

    private struct ExampleItem {
        let query: String
        let label: String?
    }

    private var examples: [ExampleItem] {
        guard let system = scopedSystem else {
            return [
                ExampleItem(query: "@cpt", label: "Procedures"),
                ExampleItem(query: "@loinc", label: "Labs"),
                ExampleItem(query: "@icd", label: "Diagnoses"),
                ExampleItem(query: "@snomed", label: "Concepts"),
                ExampleItem(query: "Diabetes", label: nil),
                ExampleItem(query: "Hypertension", label: nil)
            ]
        }

        switch system {
        case .cpt:
            return [
                ExampleItem(query: "99214", label: "Office Visit"),
                ExampleItem(query: "99213", label: "Level 3"),
                ExampleItem(query: "99396", label: "Preventive"),
                ExampleItem(query: "Telehealth", label: nil),
                ExampleItem(query: "EKG", label: nil)
            ]
        case .loinc:
            return [
                ExampleItem(query: "Hemoglobin A1c", label: "Blood"),
                ExampleItem(query: "Lipid Panel", label: "Panel"),
                ExampleItem(query: "Potassium", label: "Serum"),
                ExampleItem(query: "CBC", label: "Count"),
                ExampleItem(query: "Creatinine", label: "Renal")
            ]
        case .icd10cm:
            return [
                ExampleItem(query: "E11.9", label: "Type 2 Diabetes"),
                ExampleItem(query: "I10", label: "Essential HTN"),
                ExampleItem(query: "J45.909", label: "Asthma"),
                ExampleItem(query: "Sepsis", label: nil),
                ExampleItem(query: "Chest Pain", label: nil)
            ]
        case .snomed:
            return [
                ExampleItem(query: "Asthma", label: "Disorder"),
                ExampleItem(query: "COVID-19", label: "Infection"),
                ExampleItem(query: "Otitis Media", label: "Ear"),
                ExampleItem(query: "Fracture", label: "Injury")
            ]
        }
    }
}

// MARK: - Example Chip Component

private struct ExampleChip: View {
    let term: String
    let subtitle: String?
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            action()
        }) {
            HStack(spacing: 4) {
                Text(term)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.9))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: Metric.chipRadius + 2, style: .continuous)
                    .fill(isHovered ? color.opacity(0.16) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metric.chipRadius + 2, style: .continuous)
                    .strokeBorder(isHovered ? color.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Search for \"\(term)\"")
    }
}

// MARK: - Flow Layout for Suggestion Pills

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if width > 0 && currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            currentX += size.width + spacing
            maxHeightInRow = max(maxHeightInRow, size.height)
            height = currentY + maxHeightInRow
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        var currentX = bounds.minX
        var rows: [[(subview: LayoutSubview, size: CGSize)]] = []
        var currentRow: [(subview: LayoutSubview, size: CGSize)] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if bounds.width > 0 && currentX + size.width > bounds.maxX && currentX > bounds.minX {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                }
                currentX = bounds.minX
            }
            currentRow.append((subview, size))
            currentX += size.width + spacing
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        var currentY = bounds.minY
        for row in rows {
            guard !row.isEmpty else { continue }
            let rowWidth = row.reduce(0) { $0 + $1.size.width } + CGFloat(max(0, row.count - 1)) * spacing
            let startX = bounds.minX + max(0, (bounds.width - rowWidth) / 2)
            var x = startX
            let rowHeight = row.map(\.size.height).max() ?? 0

            for item in row {
                item.subview.place(at: CGPoint(x: x, y: currentY), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            currentY += rowHeight + spacing
        }
    }
}
