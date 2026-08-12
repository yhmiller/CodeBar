import CodeCore
import SwiftUI

/// Everything the publisher says about one code.
public struct CodeDetailView: View {
    let detail: CodeDetail?
    let isPinned: Bool
    let note: String
    let lists: [CodeList]
    let currentList: CodeList?
    let onCopy: (ClinicalCode, CopyFormat) -> Void
    let onTogglePin: (ClinicalCode) -> Void
    let onSelectCode: (ClinicalCode) -> Void
    let onSaveNote: (String) -> Void
    let onAddToList: (Int) -> Void
    let onRemoveFromList: () -> Void

    @State private var draft = ""
    @FocusState private var isEditingNote: Bool

    public var body: some View {
        if let detail {
            ScrollView {
                VStack(alignment: .leading, spacing: Metric.l) {
                    header(detail)
                    noteEditor(detail)
                    if !detail.notes.isEmpty { notes(detail) }
                    if !detail.children.isEmpty { children(detail) }
                }
                .padding(Metric.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: detail.code.id) { _, _ in draft = note }
            .onChange(of: note) { _, latest in draft = latest }
            .onAppear { draft = note }
        } else {
            ContentUnavailableView("Select a code", systemImage: "stethoscope")
        }
    }

    private func header(_ detail: CodeDetail) -> some View {
        VStack(alignment: .leading, spacing: Metric.m) {
            if !detail.ancestors.isEmpty {
                // Nearest parent last, so it reads root → leaf.
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

            HStack(spacing: Metric.s) {
                if detail.code.isBillable == false {
                    Label("Category — not valid for submission", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, Metric.s).padding(.vertical, Metric.xs)
                        .background(Color.warning.opacity(0.18))
                        .foregroundStyle(Color.warning)
                        .clipShape(Capsule())
                } else if detail.code.isBillable == true {
                    Label("Billable", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, Metric.s).padding(.vertical, Metric.xs)
                        .background(Color.confirmed.opacity(0.15))
                        .foregroundStyle(Color.confirmed)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: Metric.m) {
                Button("Copy code") { onCopy(detail.code, .codeOnly) }
                Button("Copy with description") { onCopy(detail.code, .codeAndDisplay) }
                Button(isPinned ? "Unpin" : "Pin") { onTogglePin(detail.code) }

                if lists.isEmpty {
                    // No menu when there is nothing to add to; the sidebar's
                    // New List button is the way in.
                    EmptyView()
                } else {
                    Menu("Add to List") {
                        ForEach(lists) { list in
                            Button("\(list.name)  (\(list.count))") { onAddToList(list.id) }
                        }
                    }
                    .fixedSize()
                }

                if let currentList {
                    Button("Remove from \(currentList.name)", role: .destructive) {
                        onRemoveFromList()
                    }
                }
            }
            .padding(.top, Metric.xs)
        }
    }

    /// The user's own note, kept visually distinct from the publisher's — one is
    /// authoritative, the other is a personal reminder, and confusing them in a
    /// clinical tool would be careless.
    private func noteEditor(_ detail: CodeDetail) -> some View {
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
                    // Committed when focus leaves, rather than per keystroke.
                    if !editing && draft != note { onSaveNote(draft) }
                }

            if draft != note {
                Button("Save note") { onSaveNote(draft) }
                    .controlSize(.small)
            }
        }
    }

    /// Grouped by kind so the coding rules read as rules rather than a list.
    private func notes(_ detail: CodeDetail) -> some View {
        VStack(alignment: .leading, spacing: Metric.l) {
            ForEach(CodeNote.Kind.allCases, id: \.self) { kind in
                let matching = detail.notes.filter { $0.kind == kind }
                if !matching.isEmpty {
                    VStack(alignment: .leading, spacing: Metric.xs) {
                        Text(kind.label)
                            .font(CodeTypography.sectionLabel)
                            .foregroundStyle(kind == .excludes1 ? Color.prohibition : .secondary)
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
        VStack(alignment: .leading, spacing: Metric.s) {
            Text(detail.children.count == 1
                 ? "1 code beneath this"
                 : "\(detail.children.count) codes beneath this")
                .font(CodeTypography.sectionLabel)
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
