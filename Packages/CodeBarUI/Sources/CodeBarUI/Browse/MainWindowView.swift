import CodeCore
import SwiftUI

public struct MainWindowView: View {
    @State private var model: BrowseViewModel
    @State private var searchText = ""

    @State private var isCreatingList = false
    @State private var newListName = ""
    @State private var renaming: CodeList?
    @State private var deleting: CodeList?
    private let onCopy: (ClinicalCode, CopyFormat) -> Void
    private let onTogglePin: (ClinicalCode) -> Void
    private let isPinned: (ClinicalCode) -> Bool

    private let onExportList: (String, CodeList, ListExportFormat, Bool) -> Void

    public init(
        model: BrowseViewModel,
        isPinned: @escaping (ClinicalCode) -> Bool,
        onCopy: @escaping (ClinicalCode, CopyFormat) -> Void,
        onTogglePin: @escaping (ClinicalCode) -> Void,
        onExportList: @escaping (String, CodeList, ListExportFormat, Bool) -> Void = { _, _, _, _ in }
    ) {
        _model = State(initialValue: model)
        self.isPinned = isPinned
        self.onCopy = onCopy
        self.onTogglePin = onTogglePin
        self.onExportList = onExportList
    }

    private func export(_ list: CodeList, as format: ListExportFormat, toFile: Bool) {
        Task {
            let content = await model.exportString(forList: list.id, as: format)
            onExportList(content, list, format, toFile)
        }
    }

    public var body: some View {
        NavigationSplitView {
            chapterList
        } content: {
            codeTree
        } detail: {
            CodeDetailView(
                detail: model.detail,
                note: model.note,
                onSelectCode: { model.selectedCode = $0 },
                onSaveNote: { model.saveNote($0) }
            )
        }
        .toolbar { toolbarContent }
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Copy Code") { if let code { onCopy(code, .codeOnly) } }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .help("Copy \(code?.code ?? "the selected code")")
                .disabled(code == nil)

            Menu {
                Button("Copy with Description") {
                    if let code { onCopy(code, .codeAndDisplay) }
                }
            } label: {
                Label("Copy options", systemImage: "chevron.down")
            }
            .help("Other copy formats")
            .disabled(code == nil)
        }

        ToolbarItemGroup {
            Button {
                if let code { onTogglePin(code) }
            } label: {
                Label(isCodePinned ? "Unpin" : "Pin",
                      systemImage: isCodePinned ? "pin.fill" : "pin")
            }
            .keyboardShortcut("p", modifiers: .command)
            .help(isCodePinned ? "Unpin this code" : "Pin this code")
            .disabled(code == nil)

            Menu {
                if model.lists.isEmpty {
                    Text("No lists yet")
                } else {
                    ForEach(model.lists) { list in
                        Button("\(list.name)  (\(list.count))") {
                            model.addSelectedCode(toList: list.id)
                        }
                    }
                }
                if let current = model.selectedList {
                    Divider()
                    Button("Remove from \(current.name)", role: .destructive) {
                        model.removeSelectedCodeFromCurrentList()
                    }
                }
            } label: {
                Label("Add to List", systemImage: "text.badge.plus")
            }
            .help("Add this code to one of your lists")
            .disabled(code == nil)
        }
    }

    private var code: ClinicalCode? { model.detail?.code }

    private var isCodePinned: Bool {
        model.detail.map { isPinned($0.code) } ?? false
    }

    private var chapterList: some View {
        List(selection: $model.selection) {
            if !model.lists.isEmpty {
                Section("Lists") {
                    ForEach(model.lists) { list in
                        Label(list.name, systemImage: "list.bullet.rectangle")
                            .badge(list.count)
                            .tag(SidebarSelection.list(list.id))
                            .contextMenu {
                                Button("Rename…") { renaming = list }
                                Divider()
                                Button("Copy as Text") {
                                    export(list, as: .text, toFile: false)
                                }
                                Button("Export as CSV…") {
                                    export(list, as: .csv, toFile: true)
                                }
                                Button("Export as Text…") {
                                    export(list, as: .text, toFile: true)
                                }
                                Divider()
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
        .navigationSplitViewColumnWidth(min: Metric.sidebarMinWidth,
                                        ideal: Metric.sidebarIdealWidth)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button {
                    isCreatingList = true
                } label: {
                    Label("New List", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding(Metric.m)
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
            .navigationSplitViewColumnWidth(min: Metric.contentMinWidth,
                                            ideal: Metric.contentIdealWidth)
        }
    }

    private var searchResults: some View {
        List(selection: Binding(
            get: { model.selectedCode?.id },
            set: { id in model.selectedCode = model.searchResults.first { $0.id == id }?.code }
        )) {
            ForEach(model.searchResults) { result in
                VStack(alignment: .leading, spacing: Metric.xxs) {
                    CodeRow(code: result.code, density: .list, showsSystemBadge: false)
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
        .navigationSplitViewColumnWidth(min: Metric.contentMinWidth,
                                        ideal: Metric.contentIdealWidth)
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
                CodeRow(code: code, density: .list, showsSystemBadge: false)
                    .tag(code.id)
            }
        }
        .navigationSplitViewColumnWidth(min: Metric.contentMinWidth,
                                        ideal: Metric.contentIdealWidth)
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
            CodeRow(code: node.code, density: .list, showsSystemBadge: false)
                .tag(node.id)
        }
        .onChange(of: isExpanded) { _, expanded in
            guard expanded else { return }
            Task { await node.loadChildrenIfNeeded() }
        }
    }
}

