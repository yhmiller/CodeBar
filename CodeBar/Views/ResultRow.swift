import SwiftUI

struct ResultRow: View {
    let code: ClinicalCode
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(code.system.shortLabel)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeColor.opacity(0.15))
                .foregroundStyle(badgeColor)
                .clipShape(Capsule())
                .frame(width: 72, alignment: .leading)

            Text(code.code)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(width: 92, alignment: .leading)

            Text(code.display)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer()

            if isSelected {
                Text("↵ copy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 6)
    }

    private var badgeColor: Color {
        switch code.system {
        case .icd10cm: return .blue
        case .loinc: return .purple
        case .snomed: return .green
        case .cpt: return .orange
        }
    }
}
