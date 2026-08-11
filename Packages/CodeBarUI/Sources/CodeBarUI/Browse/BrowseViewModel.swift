import CodeCore
import Observation

/// One node in the browse tree.
///
/// Children load when a node is first expanded rather than up front: ICD-10-CM
/// is 98,000 codes, and loading the whole tree to show twenty rows would be
/// wasteful and slow.
@MainActor
@Observable
public final class BrowseNode: Identifiable {
    public let code: ClinicalCode

    /// `nonisolated` so the conformance does not drag `Identifiable` into main
    /// actor isolation; the value is immutable, so reading it off the actor is safe.
    public nonisolated var id: String { code.id }

    public private(set) var children: [BrowseNode]?
    public private(set) var isLoading = false

    /// `nil` until the children are known. A code with no children is a leaf,
    /// which is what the disclosure arrow should reflect.
    public var hasChildren: Bool? {
        guard let children else { return nil }
        return !children.isEmpty
    }

    private let repository: (any CodeRepository)?

    init(code: ClinicalCode, repository: (any CodeRepository)?) {
        self.code = code
        self.repository = repository
    }

    public func loadChildrenIfNeeded() async {
        guard children == nil, !isLoading, let repository else { return }
        isLoading = true
        defer { isLoading = false }

        let found = (try? await repository.children(of: code.code, in: code.system)) ?? []
        children = found.map { BrowseNode(code: $0, repository: repository) }
    }
}

/// What the sidebar is showing: a chapter of the code tree, or one of the
/// user's own lists.
public enum SidebarSelection: Hashable, Sendable {
    case chapter(String)
    case list(Int)
}

/// Drives the main window's browse column.
@MainActor
@Observable
public final class BrowseViewModel {

    public private(set) var chapters: [String] = []
    public private(set) var lists: [CodeList] = []
    public private(set) var roots: [BrowseNode] = []
    /// Members of the selected list. Empty while a chapter is selected.
    public private(set) var listCodes: [ClinicalCode] = []
    public private(set) var detail: CodeDetail?
    public private(set) var isLoading = false

    public var selection: SidebarSelection? {
        didSet {
            guard selection != oldValue else { return }
            pendingWork = Task { await loadSelection() }
        }
    }

    /// The list currently being viewed, if any — so the detail pane can offer to
    /// remove a code from the list it was reached through.
    public var selectedList: CodeList? {
        guard case .list(let id) = selection else { return nil }
        return lists.first { $0.id == id }
    }

    public var selectedCode: ClinicalCode? {
        didSet {
            guard selectedCode?.id != oldValue?.id else { return }
            Task { await loadDetail() }
        }
    }

    /// The user's own note on the selected code, if any.
    public private(set) var note: String = ""

    private let repository: (any CodeRepository)?
    private let library: (any CodeLibraryStoring)?
    private let system: CodeSystem

    @ObservationIgnored
    public private(set) var pendingWork: Task<Void, Never>?

    public init(
        repository: (any CodeRepository)?,
        library: (any CodeLibraryStoring)? = nil,
        system: CodeSystem = .icd10cm
    ) {
        self.repository = repository
        self.library = library
        self.system = system
    }

    /// Saved on demand rather than on every keystroke: a note is prose, and
    /// writing to disk per character would be pointless churn.
    public func saveNote(_ body: String) {
        guard let library, let code = selectedCode else { return }
        note = body
        pendingWork = Task {
            try? await library.setNote(body, for: code)
        }
    }

    /// True when the installed set carried no hierarchy — an older import, or
    /// one made without the tabular file. The UI says so rather than showing an
    /// empty column that looks broken.
    public var hasHierarchy: Bool {
        !chapters.isEmpty
    }

    public func load() async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }

        chapters = (try? await repository.chapters(in: system)) ?? []
        await reloadLists()

        if selection == nil, let first = chapters.first {
            selection = .chapter(first)
        }
    }

    public func reloadLists() async {
        lists = (try? await library?.lists()).flatMap { $0 } ?? []
    }

    private func loadSelection() async {
        switch selection {
        case .chapter(let chapter):
            listCodes = []
            await loadRoots(inChapter: chapter)
        case .list(let id):
            roots = []
            listCodes = (try? await library?.codes(inList: id)).flatMap { $0 } ?? []
        case nil:
            roots = []
            listCodes = []
        }
    }

    private func loadRoots(inChapter chapter: String) async {
        guard let repository else {
            roots = []
            return
        }
        let found = (try? await repository.roots(inChapter: chapter, of: system)) ?? []
        roots = found.map { BrowseNode(code: $0, repository: repository) }
    }

    // MARK: - Lists

    public func createList(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let library else { return }

        pendingWork = Task {
            let created = try? await library.createList(named: trimmed, detail: nil)
            await reloadLists()
            if let created { selection = .list(created.id) }
        }
    }

    public func renameList(_ id: Int, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let library else { return }

        pendingWork = Task {
            try? await library.renameList(id, to: trimmed)
            await reloadLists()
        }
    }

    public func deleteList(_ id: Int) {
        guard let library else { return }
        pendingWork = Task {
            try? await library.deleteList(id)
            await reloadLists()
            // Falling back to the first chapter, rather than leaving the window
            // pointed at something that no longer exists.
            if case .list(id) = selection {
                selection = chapters.first.map { SidebarSelection.chapter($0) }
            }
        }
    }

    public func addSelectedCode(toList id: Int) {
        guard let library, let code = selectedCode else { return }
        pendingWork = Task {
            try? await library.addCode(code, toList: id)
            await reloadLists()
            if case .list(id) = selection {
                listCodes = (try? await library.codes(inList: id)) ?? []
            }
        }
    }

    public func removeSelectedCodeFromCurrentList() {
        guard let library, let code = selectedCode, case .list(let id) = selection else { return }
        pendingWork = Task {
            try? await library.removeCode(code, fromList: id)
            await reloadLists()
            listCodes = (try? await library.codes(inList: id)) ?? []
        }
    }

    private func loadDetail() async {
        guard let repository, let code = selectedCode else {
            detail = nil
            note = ""
            return
        }
        detail = try? await repository.detail(for: code)
        note = (try? await library?.note(for: code)) .flatMap { $0 } ?? ""
    }
}
