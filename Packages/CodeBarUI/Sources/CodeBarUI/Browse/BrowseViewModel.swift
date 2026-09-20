import CodeCore
import Observation

@MainActor
@Observable
public final class BrowseNode: Identifiable {
    public let code: ClinicalCode

    public nonisolated var id: String { code.id }

    public private(set) var children: [BrowseNode]?
    public private(set) var isLoading = false

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

public enum SidebarSelection: Hashable, Sendable {
    case chapter(String)
    case list(Int)
}

@MainActor
@Observable
public final class BrowseViewModel {

    public private(set) var chapters: [String] = []
    public private(set) var lists: [CodeList] = []
    public private(set) var roots: [BrowseNode] = []
    public private(set) var listCodes: [ClinicalCode] = []
    public private(set) var detail: CodeDetail?
    public private(set) var isLoading = false

    public var selection: SidebarSelection? {
        didSet {
            guard selection != oldValue else { return }
            pendingWork = Task { await loadSelection() }
        }
    }

    public var selectedList: CodeList? {
        guard case .list(let id) = selection else { return nil }
        return lists.first { $0.id == id }
    }

    public var selectedCode: ClinicalCode? {
        didSet {
            guard selectedCode?.id != oldValue?.id else { return }
            pendingWork = Task { await loadDetail() }
        }
    }

    public private(set) var note: String = ""

    public private(set) var searchResults: [SearchResult] = []
    public private(set) var isSearching = false

    public private(set) var installedCodeCount = 0

    private let repository: (any CodeRepository)?
    private let library: (any CodeLibraryStoring)?
    private let preferences: (any PreferencesStoring)?
    private let system: CodeSystem

    private var preferredIDs: Set<String> = []
    private var ownAbbreviations: [String: String] = [:]

    @ObservationIgnored
    public private(set) var pendingWork: Task<Void, Never>?

    @ObservationIgnored
    private lazy var searchRunner = DebouncedSearchRunner(
        repository: repository, debounce: debounce
    )

    @ObservationIgnored
    public var pendingSearch: Task<Void, Never>? { searchRunner.pending }

    private let debounce: Duration

    public init(
        repository: (any CodeRepository)?,
        library: (any CodeLibraryStoring)? = nil,
        preferences: (any PreferencesStoring)? = nil,
        system: CodeSystem = .icd10cm,
        debounce: Duration = DEFAULT_SEARCH_DEBOUNCE
    ) {
        self.repository = repository
        self.library = library
        self.preferences = preferences
        self.system = system
        self.debounce = debounce
    }

    // MARK: - Searching

    public func search(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearching = !trimmed.isEmpty

        let query = SearchQuery(
            raw: trimmed,
            systems: preferences?.enabledSystems ?? [],
            preferredCodes: preferredIDs,
            abbreviations: ownAbbreviations
        )

        searchRunner.run(query) { [weak self] found in
            self?.searchResults = found
        }
    }

    public func saveNote(_ body: String) {
        guard let library, let code = selectedCode else { return }
        note = body
        pendingWork = Task {
            try? await library.setNote(body, for: code)
        }
    }

    public var hasHierarchy: Bool {
        !chapters.isEmpty
    }

    public func load() async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }

        chapters = (try? await repository.chapters(in: system)) ?? []
        await reloadLists()
        await reloadPreferredCodes()
        installedCodeCount = (try? await repository.codeCount()) ?? 0

        if selection == nil, let first = chapters.first {
            selection = .chapter(first)
        }
    }

    public func exportString(forList id: Int, as format: ListExportFormat) async -> String {
        let codes = (try? await library?.codes(inList: id)).flatMap { $0 } ?? []
        return format.string(for: codes)
    }

    public func reloadLists() async {
        lists = (try? await library?.lists()).flatMap { $0 } ?? []
    }

    private func reloadPreferredCodes() async {
        let pinned = (try? await library?.pinnedCodes()).flatMap { $0 } ?? []
        let used = (try? await library?.mostUsedCodes(limit: PREFERRED_CODE_LIMIT))
            .flatMap { $0 } ?? []
        preferredIDs = Set((pinned + used).map(\.id))

        let own = (try? await library?.abbreviations()).flatMap { $0 } ?? []
        ownAbbreviations = own.expansionsByTerm
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
