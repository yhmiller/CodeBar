import CodeCore
import SwiftUI

public struct CodeDetailView: View {
    let detail: CodeDetail?
    let note: String
    let onSelectCode: (ClinicalCode) -> Void
    let onSaveNote: (String) -> Void

    @State private var draft = ""
    @State private var isWritingNote = false
    @FocusState private var isEditingNote: Bool

    public init(
        detail: CodeDetail?,
        note: String,
        onSelectCode: @escaping (ClinicalCode) -> Void,
        onSaveNote: @escaping (String) -> Void
    ) {
        self.detail = detail
        self.note = note
        self.onSelectCode = onSelectCode
        self.onSaveNote = onSaveNote
    }

    public var body: some View {
        if let detail {
            ScrollView {
                VStack(alignment: .leading, spacing: Metric.l) {
                    header(detail)
                    if !detail.notes.isEmpty { publisherNotes(detail) }
                    if !detail.children.isEmpty { children(detail) }
                    noteEditor
                }
                .padding(Metric.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: detail.code.id) { _, _ in
                draft = note
                isWritingNote = false
            }
            .onChange(of: note) { _, latest in draft = latest }
            .onAppear { draft = note }
        } else {
            ContentUnavailableView("Select a code", systemImage: "stethoscope")
        }
    }

    private func header(_ detail: CodeDetail) -> some View {
        VStack(alignment: .leading, spacing: Metric.m) {
            if !detail.ancestors.isEmpty {
                HStack(spacing: Metric.xs) {
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
                .font(CodeTypography.codeHero)
            Text(detail.code.display)
                .font(.title3)
                .foregroundStyle(.secondary)

            billability(detail)
        }
    }

    @ViewBuilder
    private func billability(_ detail: CodeDetail) -> some View {
        if detail.code.isBillable == false {
            Label(NOT_BILLABLE_LABEL, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.medium))
                .padding(.horizontal, Metric.s).padding(.vertical, Metric.xs)
                .semanticChip(Color.warning, in: Capsule())
                .accessibilityLabel(NOT_BILLABLE_SPOKEN_LABEL)
        } else if detail.code.isBillable == true {
            Label("Billable", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .padding(.horizontal, Metric.s).padding(.vertical, Metric.xs)
                .semanticChip(Color.confirmed, in: Capsule())
        }
    }

    private func publisherNotes(_ detail: CodeDetail) -> some View {
        VStack(alignment: .leading, spacing: Metric.l) {
            ForEach(CodeNote.Kind.allCases, id: \.self) { kind in
                let matching = detail.notes.filter { $0.kind == kind }
                if !matching.isEmpty {
                    noteGroup(kind, matching)
                }
            }
        }
    }

    @ViewBuilder
    private func noteGroup(_ kind: CodeNote.Kind, _ notes: [CodeNote]) -> some View {
        let isProhibition = kind == .excludes1

        VStack(alignment: .leading, spacing: Metric.xs) {
            Text(kind.label)
                .font(CodeTypography.sectionLabel)
                .foregroundStyle(isProhibition ? AnyShapeStyle(Color.prohibition)
                                               : AnyShapeStyle(.secondary))
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                Text(note.text)
                    .font(.callout)
                    .textSelection(.enabled)
            }
        }
        .modifier(ProhibitionContainer(isActive: isProhibition))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isProhibition
                            ? "\(kind.label). Never code these together."
                            : kind.label)
    }

    private func children(_ detail: CodeDetail) -> some View {
        VStack(alignment: .leading, spacing: Metric.s) {
            Text(detail.children.count == 1
                 ? "1 code beneath this"
                 : "\(detail.children.count) codes beneath this")
                .font(CodeTypography.sectionLabel)
                .foregroundStyle(.secondary)
            ForEach(detail.children) { child in
                Button { onSelectCode(child) } label: {
                    CodeRow(code: child, density: .compact, showsSystemBadge: false)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Show this code")
            }
        }
    }

    @ViewBuilder
    private var noteEditor: some View {
        if draft.isEmpty && !isWritingNote {
            Button {
                isWritingNote = true
                isEditingNote = true
            } label: {
                Label("Add a note", systemImage: "plus")
                    .font(.callout)
            }
            .buttonStyle(.borderless)
        } else {
            VStack(alignment: .leading, spacing: Metric.s) {
                Text("Your note")
                    .font(CodeTypography.sectionLabel)
                    .foregroundStyle(.secondary)

                TextEditor(text: $draft)
                    .font(.callout)
                    .frame(minHeight: Metric.noteEditorMinHeight)
                    .padding(Metric.s)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: Metric.rowRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Metric.rowRadius)
                            .stroke(Color.secondary.opacity(0.25))
                    )
                    .focused($isEditingNote)
                    .onChange(of: isEditingNote) { _, editing in
                        guard !editing else { return }
                        if draft != note { onSaveNote(draft) }
                        if draft.isEmpty { isWritingNote = false }
                    }

                if draft != note {
                    Text("Unsaved — click away to keep it")
                        .font(CodeTypography.metadata)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ProhibitionContainer: ViewModifier {
    let isActive: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if isActive {
            content
                .padding(.leading, Metric.m)
                .padding(.vertical, Metric.s)
                .padding(.trailing, Metric.s)
                .background(contrast == .increased
                            ? Color.clear
                            : Color.prohibition.opacity(0.10))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.prohibition)
                        .frame(width: contrast == .increased ? 4 : 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: Metric.chipRadius))
        } else {
            content
        }
    }
}
