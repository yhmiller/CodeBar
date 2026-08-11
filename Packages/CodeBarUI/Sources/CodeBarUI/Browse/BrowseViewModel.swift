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

/// Drives the main window's browse column.
@MainActor
@Observable
public final class BrowseViewModel {

    public private(set) var chapters: [String] = []
    public private(set) var roots: [BrowseNode] = []
    public private(set) var detail: CodeDetail?
    public private(set) var isLoading = false

    public var selectedChapter: String? {
        didSet {
            guard selectedChapter != oldValue else { return }
            Task { await loadRoots() }
        }
    }

    public var selectedCode: ClinicalCode? {
        didSet {
            guard selectedCode?.id != oldValue?.id else { return }
            Task { await loadDetail() }
        }
    }

    private let repository: (any CodeRepository)?
    private let system: CodeSystem

    public init(repository: (any CodeRepository)?, system: CodeSystem = .icd10cm) {
        self.repository = repository
        self.system = system
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
        if selectedChapter == nil {
            selectedChapter = chapters.first
        }
    }

    private func loadRoots() async {
        guard let repository, let chapter = selectedChapter else {
            roots = []
            return
        }
        let found = (try? await repository.roots(inChapter: chapter, of: system)) ?? []
        roots = found.map { BrowseNode(code: $0, repository: repository) }
    }

    private func loadDetail() async {
        guard let repository, let code = selectedCode else {
            detail = nil
            return
        }
        detail = try? await repository.detail(for: code)
    }
}
