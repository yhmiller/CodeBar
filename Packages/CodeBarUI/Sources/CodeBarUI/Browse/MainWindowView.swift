import CodeCore
import SwiftUI

/// The main window: browse the code hierarchy the menu bar panel cannot show.
///
/// The panel stays the fast path — hotkey, type, copy, gone. This is for the
/// work that does not fit in two seconds: seeing where a code sits, what sits
/// beneath it, and what the publisher says about coding it.
public struct MainWindowView: View {
    @State private var model: BrowseViewModel
    private let onCopy: (ClinicalCode, CopyFormat) -> Void
    private let onTogglePin: (ClinicalCode) -> Void
    private let isPinned: (ClinicalCode) -> Bool

    public init(
        model: BrowseViewModel,
        isPinned: @escaping (ClinicalCode) -> Bool,
        onCopy: @escaping (ClinicalCode, CopyFormat) -> Void,
        onTogglePin: @escaping (ClinicalCode) -> Void
    ) {
        _model = State(initialValue: model)
        self.isPinned = isPinned
        self.onCopy = onCopy
        self.onTogglePin = onTogglePin
    }

    public var body: some View {
        NavigationSplitView {
            chapterList
        } content: {
            codeTree
        } detail: {
            CodeDetailView(
                detail: model.detail,
                isPinned: model.detail.map { isPinned($0.code) } ?? false,
                onCopy: onCopy,
                onTogglePin: onTogglePin,
                onSelectCode: { model.selectedCode = $0 }
            )
        }
        .navigationTitle("CodeBar")
        .task { await model.load() }
    }

    private var chapterList: some View {
        List(model.chapters, id: \.self, selection: $model.selectedChapter) { chapter in
            Text(chapter).lineLimit(3)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        .overlay {
            if !model.hasHierarchy && !model.isLoading {
                ContentUnavailableView(
                    "No hierarchy installed",
                    systemImage: "list.bullet.indent",
                    description: Text("Re-import ICD-10-CM with the tabular file to browse "
                                      + "by chapter:\n\nimport_icd10_cms.py … --tabular "
                                      + "icd10cm_tabular_2026.xml")
                )
                .padding()
            }
        }
    }

    private var codeTree: some View {
        List(selection: Binding(
            get: { model.selectedCode?.id },
            set: { id in model.selectedCode = findCode(id, in: model.roots) }
        )) {
            ForEach(model.roots) { node in
                BrowseNodeRow(node: node)
            }
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 360)
    }

    /// The selection binding carries an id, so the chosen node has to be found
    /// again in the loaded tree.
    private func findCode(_ id: String?, in nodes: [BrowseNode]) -> ClinicalCode? {
        guard let id else { return nil }
        for node in nodes {
            if node.id == id { return node.code }
            if let children = node.children, let found = findCode(id, in: children) {
                return found
            }
        }
        return nil
    }
}

/// A row in the tree, loading its children the first time it is opened.
struct BrowseNodeRow: View {
    @Bindable var node: BrowseNode
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if let children = node.children {
                ForEach(children) { child in
                    BrowseNodeRow(node: child)
                }
            } else if node.isLoading {
                ProgressView().controlSize(.small)
            }
        } label: {
            CodeRowLabel(code: node.code)
                .tag(node.id)
        }
        .onChange(of: isExpanded) { _, expanded in
            guard expanded else { return }
            Task { await node.loadChildrenIfNeeded() }
        }
    }
}

struct CodeRowLabel: View {
    let code: ClinicalCode

    var body: some View {
        HStack(spacing: 8) {
            Text(code.code)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(code.isBillable == false ? .secondary : .primary)
            Text(code.display)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }
}
