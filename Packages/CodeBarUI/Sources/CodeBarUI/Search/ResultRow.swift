import CodeCore
import SwiftUI

private let BADGE_COLUMN_WIDTH: CGFloat = 72
private let CODE_COLUMN_WIDTH: CGFloat = 92

struct ResultRow: View {
    let code: ClinicalCode
    let isSelected: Bool
    var isPinned: Bool = false
    var onTogglePin: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(code.system.shortLabel)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeColor.opacity(0.15))
                .foregroundStyle(badgeColor)
                .clipShape(Capsule())
                .frame(width: BADGE_COLUMN_WIDTH, alignment: .leading)

            Text(code.code)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(width: CODE_COLUMN_WIDTH, alignment: .leading)

            Text(code.display)
                .lineLimit(1)
                .foregroundStyle(.primary)

            if code.isBillable == false {
                headerBadge
            }

            Spacer()

            if let onTogglePin {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.caption)
                        .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin this code" : "Pin this code")
                .accessibilityLabel(isPinned ? "Unpin \(code.code)" : "Pin \(code.code)")
            }

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

    /// Marks a code the publisher says cannot go on a claim.
    ///
    /// Shown as text rather than colour alone: this is the one piece of
    /// information in the row that can turn a correct-looking lookup into a
    /// denied claim, so it must survive being glanced at, and must not depend on
    /// the reader distinguishing two shades of grey.
    private var headerBadge: some View {
        Text("category - not billable")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.18))
            .foregroundStyle(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .fixedSize()
            .accessibilityLabel("Category header, not valid for submission")
    }

    private var badgeColor: Color {
        switch code.system {
        case .icd10cm: .blue
        case .loinc: .purple
        case .snomed: .green
        case .cpt: .orange
        }
    }
}
