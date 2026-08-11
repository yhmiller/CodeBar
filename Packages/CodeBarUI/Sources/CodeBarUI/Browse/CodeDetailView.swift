import CodeCore
import SwiftUI

/// Everything the publisher says about one code.
public struct CodeDetailView: View {
    let detail: CodeDetail?
    let isPinned: Bool
    let onCopy: (ClinicalCode, CopyFormat) -> Void
    let onTogglePin: (ClinicalCode) -> Void
    let onSelectCode: (ClinicalCode) -> Void

    public var body: some View {
        if let detail {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(detail)
                    if !detail.notes.isEmpty { notes(detail) }
                    if !detail.children.isEmpty { children(detail) }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("Select a code", systemImage: "stethoscope")
        }
    }

    private func header(_ detail: CodeDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !detail.ancestors.isEmpty {
                // Nearest parent last, so it reads root → leaf.
                HStack(spacing: 4) {
                    ForEach(detail.ancestors.reversed()) { ancestor in
                        Button(ancestor.code) { onSelectCode(ancestor) }
                            .buttonStyle(.link)
                            .font(.caption)
                        Text("›").font(.caption).foregroundStyle(.tertiary)
                    }
                    Text(detail.code.code).font(.caption).foregroundStyle(.secondary)
                }
            }

            Text(detail.code.code)
                .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
            Text(detail.code.display)
                .font(.title3)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if detail.code.isBillable == false {
                    Label("Category — not valid for submission", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.18))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                } else if detail.code.isBillable == true {
                    Label("Billable", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 10) {
                Button("Copy code") { onCopy(detail.code, .codeOnly) }
                Button("Copy with description") { onCopy(detail.code, .codeAndDisplay) }
                Button(isPinned ? "Unpin" : "Pin") { onTogglePin(detail.code) }
            }
            .padding(.top, 4)
        }
    }

    /// Grouped by kind so the coding rules read as rules rather than a list.
    private func notes(_ detail: CodeDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(CodeNote.Kind.allCases, id: \.self) { kind in
                let matching = detail.notes.filter { $0.kind == kind }
                if !matching.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(kind == .excludes1 ? Color.red : .secondary)
                        ForEach(Array(matching.enumerated()), id: \.offset) { _, note in
                            Text(note.text)
                                .font(.callout)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    private func children(_ detail: CodeDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(detail.children.count) codes beneath this")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(detail.children) { child in
                Button { onSelectCode(child) } label: {
                    CodeRowLabel(code: child)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
