import CodeCore
import SwiftUI

/// Everything the publisher says about one code.
///
/// Reading surface only. Copy, pin and list actions used to live here as four
/// equal-weight buttons inside the scroll view — no primary among them, no
/// shortcuts, and they scrolled away with the content. They belong to the
/// window, so they are in its toolbar now and this view has no action callbacks
/// left except navigation and the user's own note.
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
                // Order is the point. The publisher's coding rules come before
                // the user's own note: an always-open editor used to sit between
                // the code and the `Excludes 1` rules that mean *never code
                // these together*, so a personal reminder outranked the fact
                // that gets a claim denied.
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

    /// Grouped by kind so the coding rules read as rules rather than a list.
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

    /// `Excludes 1` gets a container; the other kinds do not.
    ///
    /// It is the only content in the app that means "this combination will be
    /// rejected", and red label text alone does not survive being skimmed. The
    /// contrast against the plainer kinds is the point — if everything were
    /// boxed, nothing would read as the rule that stops a claim.
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
            // Real rows, not bare labels: these are the fastest path from a
            // category to the billable child that can actually go on a claim.
            //
            // Buttons rather than a tap gesture, so they are focusable, reachable
            // under Full Keyboard Access and activated by Return. A gesture is
            // invisible to every input except the pointer.
            ForEach(detail.children) { child in
                Button { onSelectCode(child) } label: {
                    CodeRow(code: child, density: .compact, showsSystemBadge: false)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Show this code")
            }
        }
    }

    /// The user's own note, kept visually distinct from the publisher's — one is
    /// authoritative, the other is a personal reminder, and confusing them in a
    /// clinical tool would be careless.
    ///
    /// Collapsed to a single button until there is something to show. The
    /// permanently-open editor paid about 140 points on every code for a feature
    /// used on a few, and it paid them above the coding rules.
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
                        // Committed when focus leaves, rather than per keystroke.
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

/// Wraps a note group in the prohibition colour, or leaves it alone.
///
/// A modifier rather than a branch at the call site, so the two paths cannot
/// drift apart in padding and the group's own layout is written once.
private struct ProhibitionContainer: ViewModifier {
    let isActive: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if isActive {
            content
                .padding(.leading, Metric.m)
                .padding(.vertical, Metric.s)
                .padding(.trailing, Metric.s)
                // The left rule carries the meaning on its own, so under
                // Increase Contrast the tint simply goes rather than being
                // replaced — a fill and a border would fight each other here.
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
