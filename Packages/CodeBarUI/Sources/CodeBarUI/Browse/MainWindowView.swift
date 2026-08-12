import CodeCore
import SwiftUI

/// The main window: browse the code hierarchy the menu bar panel cannot show.
///
/// The panel stays the fast path — hotkey, type, copy, gone. This is for the
/// work that does not fit in two seconds: seeing where a code sits, what sits
/// beneath it, and what the publisher says about coding it.
public struct MainWindowView: View {
    @State private var model: BrowseViewModel

    /// The field owns its text and pushes one way into the model — the same rule
    /// the panel follows. Letting the model drive a text field makes the query
    /// walk backwards: assigning results re-renders, which pushes a stale query
    /// back into the field, which searches again.
    @State private var searchText = ""

    @State private var isCreatingList = false
    @State private var newListName = ""
    @State private var renaming: CodeList?
    @State private var deleting: CodeList?
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
                note: model.note,
                lists: model.lists,
                currentList: model.selectedList,
                onCopy: onCopy,
                onTogglePin: onTogglePin,
                onSelectCode: { model.selectedCode = $0 },
                onSaveNote: { model.saveNote($0) },
                onAddToList: { model.addSelectedCode(toList: $0) },
                onRemoveFromList: { model.removeSelectedCodeFromCurrentList() }
            )
        }
        .navigationTitle(model.isSearching
                         ? "Search"
                         : (model.selectedList?.name ?? "CodeBar"))
        .task { await model.load() }
        .alert("New List", isPresented: $isCreatingList) {
            TextField("Name", text: $newListName)
            Button("Create") {
                model.createList(named: newListName)
                newListName = ""
            }
            Button("Cancel", role: .cancel) { newListName = "" }
        } message: {
            Text("A problem list, an encounter template, or whatever you reach for often.")
        }
        .alert("Rename List", isPresented: .init(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Name", text: $newListName)
            Button("Rename") {
                if let list = renaming { model.renameList(list.id, to: newListName) }
                renaming = nil
                newListName = ""
            }
            Button("Cancel", role: .cancel) { renaming = nil; newListName = "" }
        }
        .confirmationDialog(
            "Delete \(deleting?.name ?? "")?",
            isPresented: .init(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let list = deleting { model.deleteList(list.id) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("The list is removed. The codes themselves, your pins and your notes "
                 + "are not affected.")
        }
    }

    private var chapterList: some View {
        List(selection: $model.selection) {
            if !model.lists.isEmpty {
                Section("Lists") {
                    ForEach(model.lists) { list in
                        Label {
                            HStack {
                                Text(list.name)
                                Spacer()
                                Text("\(list.count)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        } icon: {
                            Image(systemName: "list.bullet.rectangle")
                        }
                        .tag(SidebarSelection.list(list.id))
                        .contextMenu {
                            Button("Rename…") { renaming = list }
                            Button("Delete", role: .destructive) { deleting = list }
                        }
                    }
                }
            }

            Section("Browse") {
                ForEach(model.chapters, id: \.self) { chapter in
                    Text(chapter)
                        .lineLimit(3)
                        .tag(SidebarSelection.chapter(chapter))
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 240, ideal: 300)
        .safeAreaInset(edge: .bottom) {
            // The bar needs its own ground and a divider: without them the list
            // scrolls *underneath* a transparent button and the two overlap.
            VStack(spacing: 0) {
                Divider()
                Button {
                    isCreatingList = true
                } label: {
                    Label("New List", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding(10)
            }
            .background(.bar)
        }
        .overlay {
            if !model.hasHierarchy && !model.isLoading && model.lists.isEmpty {
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
        contentColumn
            .searchable(text: $searchText, placement: .toolbar,
                        prompt: "Search all \(model.installedCodeCount) codes")
            .onChange(of: searchText) { _, text in model.search(text) }
    }

    @ViewBuilder
    private var contentColumn: some View {
        if model.isSearching {
            searchResults
        } else if let list = model.selectedList {
            listContents(list)
        } else {
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
    }

    /// Search covers the whole code set, so a result carries its chapter — the
    /// tree that would otherwise give it context is not on screen.
    private var searchResults: some View {
        List(selection: Binding(
            get: { model.selectedCode?.id },
            set: { id in model.selectedCode = model.searchResults.first { $0.id == id }?.code }
        )) {
            ForEach(model.searchResults) { result in
                VStack(alignment: .leading, spacing: 2) {
                    CodeRowLabel(code: result.code)
                    if let chapter = result.code.chapter {
                        Text(chapter)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .tag(result.id)
            }
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 360)
        .overlay {
            if model.searchResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private func listContents(_ list: CodeList) -> some View {
        List(selection: Binding(
            get: { model.selectedCode?.id },
            set: { id in model.selectedCode = model.listCodes.first { $0.id == id } }
        )) {
            ForEach(model.listCodes) { code in
                CodeRowLabel(code: code).tag(code.id)
            }
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 360)
        .overlay {
            if model.listCodes.isEmpty {
                ContentUnavailableView(
                    "\(list.name) is empty",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Find a code by browsing or searching, then use "
                                      + "Add to List in its detail pane.")
                )
                .padding()
            }
        }
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
