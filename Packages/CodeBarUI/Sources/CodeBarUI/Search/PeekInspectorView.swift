import CodeCore
import SwiftUI

public struct PeekInspectorView: View {
    let code: ClinicalCode
    let detail: CodeDetail?
    let note: String?
    let isLoading: Bool
    let isPinned: Bool

    let onCopy: (CopyFormat) -> Void
    let onTogglePin: () -> Void
    let onOpenInWindow: (() -> Void)?
    let onDismiss: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    public init(
        code: ClinicalCode,
        detail: CodeDetail?,
        note: String?,
        isLoading: Bool = false,
        isPinned: Bool = false,
        onCopy: @escaping (CopyFormat) -> Void,
        onTogglePin: @escaping () -> Void,
        onOpenInWindow: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.code = code
        self.detail = detail
        self.note = note
        self.isLoading = isLoading
        self.isPinned = isPinned
        self.onCopy = onCopy
        self.onTogglePin = onTogglePin
        self.onOpenInWindow = onOpenInWindow
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Metric.m) {
                    header
                    statusChips
                    if let chapter = code.chapter ?? detail?.code.chapter, !chapter.isEmpty {
                        chapterContext(chapter)
                    }
                    if let ancestors = detail?.ancestors, !ancestors.isEmpty {
                        ancestorBreadcrumb(ancestors)
                    }
                    notesSection
                    personalNoteSection
                    childrenSummary
                }
                .padding(Metric.l)
            }
            .frame(maxHeight: Metric.resultListMaxHeight)

            Divider()
            actionBar
        }
        .background(.ultraThinMaterial.opacity(0.5))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Metric.xxs) {
                HStack(spacing: Metric.s) {
                    Text(code.code)
                        .font(CodeTypography.codeHero)
                        .foregroundStyle(.primary)

                    Text(code.system.rawValue)
                        .font(CodeTypography.metadata.weight(.semibold))
                        .padding(.horizontal, Metric.s)
                        .padding(.vertical, Metric.xxs)
                        .semanticChip(Color.systemBadge, in: Capsule())

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    }
                }

                Text(code.display)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Metric.s)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Close peek (Space or Esc)")
        }
    }

    // MARK: - Status Chips

    @ViewBuilder
    private var statusChips: some View {
        HStack(spacing: Metric.s) {
            if code.isBillable == false {
                Label(NOT_BILLABLE_LABEL, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, Metric.s)
                    .padding(.vertical, Metric.xs)
                    .semanticChip(Color.warning, in: RoundedRectangle(cornerRadius: Metric.chipRadius))
            } else if code.isBillable == true {
                Label("Billable", systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, Metric.s)
                    .padding(.vertical, Metric.xs)
                    .semanticChip(Color.confirmed, in: RoundedRectangle(cornerRadius: Metric.chipRadius))
            }

            if code.isUnspecified == true {
                Label(UNSPECIFIED_LABEL, systemImage: "exclamationmark.circle.fill")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, Metric.s)
                    .padding(.vertical, Metric.xs)
                    .semanticChip(Color.warning, in: RoundedRectangle(cornerRadius: Metric.chipRadius))
            }
        }
    }

    // MARK: - Hierarchy

    private func chapterContext(_ chapter: String) -> some View {
        HStack(spacing: Metric.xs) {
            Image(systemName: "folder")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(chapter)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private func ancestorBreadcrumb(_ ancestors: [ClinicalCode]) -> some View {
        HStack(spacing: Metric.xs) {
            ForEach(ancestors.reversed()) { ancestor in
                Text(ancestor.code)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Text("›")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(code.code)
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Notes & Coding Rules

    @ViewBuilder
    private var notesSection: some View {
        if let notes = detail?.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: Metric.s) {
                ForEach(CodeNote.Kind.allCases, id: \.self) { kind in
                    let matching = notes.filter { $0.kind == kind }
                    if !matching.isEmpty {
                        noteCard(kind: kind, notes: matching)
                    }
                }
            }
        }
    }

    private func noteCard(kind: CodeNote.Kind, notes: [CodeNote]) -> some View {
        let isProhibition = kind == .excludes1
        return VStack(alignment: .leading, spacing: Metric.xs) {
            HStack(spacing: 4) {
                if isProhibition {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.prohibition)
                }
                Text(kind.label)
                    .font(CodeTypography.sectionLabel)
                    .foregroundStyle(isProhibition ? AnyShapeStyle(Color.prohibition) : AnyShapeStyle(.secondary))
            }

            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                Text(note.text)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, isProhibition ? Metric.m : Metric.s)
        .padding(.vertical, Metric.xs)
        .padding(.trailing, Metric.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isProhibition
                ? (contrast == .increased ? Color.clear : Color.prohibition.opacity(0.10))
                : Color.primary.opacity(0.03)
        )
        .overlay(alignment: .leading) {
            if isProhibition {
                Rectangle()
                    .fill(Color.prohibition)
                    .frame(width: contrast == .increased ? 4 : 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Metric.chipRadius))
    }

    // MARK: - Personal Note

    @ViewBuilder
    private var personalNoteSection: some View {
        if let note, !note.isEmpty {
            VStack(alignment: .leading, spacing: Metric.xs) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                    Text("Your note")
                        .font(CodeTypography.sectionLabel)
                        .foregroundStyle(.secondary)
                }

                Text(note)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Metric.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Metric.chipRadius))
        }
    }

    // MARK: - Children

    @ViewBuilder
    private var childrenSummary: some View {
        if let children = detail?.children, !children.isEmpty {
            HStack(spacing: Metric.xs) {
                Image(systemName: "list.bullet.indent")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(children.count == 1
                     ? "1 code beneath this category"
                     : "\(children.count) codes beneath this category")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: Metric.s) {
            Button("Copy") {
                onCopy(.codeOnly)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("Copy code (Return)")

            Button("With Desc") {
                onCopy(.codeAndDisplay)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Copy code with description (Shift+Return)")

            Button {
                onTogglePin()
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.caption)
                    .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(isPinned ? "Unpin this code (⌘P)" : "Pin this code (⌘P)")

            Spacer(minLength: Metric.xs)

            if let onOpenInWindow {
                Button {
                    onOpenInWindow()
                } label: {
                    Label("Browse", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .font(.caption)
                .help("Open in Browse Window (⌘Return)")
            }
        }
        .padding(.horizontal, Metric.l)
        .padding(.vertical, Metric.s)
        .background(.bar)
    }
}
