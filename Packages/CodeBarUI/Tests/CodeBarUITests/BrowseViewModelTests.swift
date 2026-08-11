import CodeCore
import Testing
@testable import CodeBarUI

/// A repository with a real ICD-10-shaped tree behind it.
actor TreeRepository: CodeRepository {
    private let tree: [ClinicalCode] = [
        ClinicalCode(code: "E11", display: "Type 2 diabetes mellitus", system: .icd10cm,
                     isBillable: false, chapter: "Endocrine"),
        ClinicalCode(code: "E11.2", display: "…with kidney complications", system: .icd10cm,
                     isBillable: false, parent: "E11", chapter: "Endocrine"),
        ClinicalCode(code: "E11.21", display: "…with diabetic nephropathy", system: .icd10cm,
                     isBillable: true, parent: "E11.2", chapter: "Endocrine"),
        ClinicalCode(code: "I10", display: "Essential hypertension", system: .icd10cm,
                     isBillable: true, chapter: "Circulatory")
    ]

    private(set) var childRequests: [String?] = []

    func search(_ query: SearchQuery) async throws -> [SearchResult] { [] }
    func manifests() async throws -> [CodeSetManifest] { [] }
    func codeCount() async throws -> Int { tree.count }
    @discardableResult func ingest(_ codeSet: CodeSetImport) async throws -> IngestSummary {
        IngestSummary(processed: 0, installedBefore: 0, installedAfter: 0, systems: [])
    }
    @discardableResult func removeCodeSet(_ system: CodeSystem) async throws -> Int { 0 }

    func children(of parent: String?, in system: CodeSystem) async throws -> [ClinicalCode] {
        childRequests.append(parent)
        return tree.filter { $0.parent == parent }
    }

    func chapters(in system: CodeSystem) async throws -> [String] {
        ["Endocrine", "Circulatory"]
    }

    func roots(inChapter chapter: String, of system: CodeSystem) async throws -> [ClinicalCode] {
        tree.filter { $0.chapter == chapter && $0.parent == nil }
    }

    func detail(for code: ClinicalCode) async throws -> CodeDetail? {
        guard let found = tree.first(where: { $0.code == code.code }) else { return nil }
        var ancestors: [ClinicalCode] = []
        var next = found.parent
        while let parent = next, let ancestor = tree.first(where: { $0.code == parent }) {
            ancestors.append(ancestor)
            next = ancestor.parent
        }
        return CodeDetail(
            code: found,
            ancestors: ancestors,
            children: tree.filter { $0.parent == found.code },
            notes: found.code == "E11"
                ? [CodeNote(kind: .excludes1, text: "type 1 diabetes mellitus (E10.-)")]
                : []
        )
    }
}

@Suite("BrowseViewModel")
@MainActor
struct BrowseViewModelTests {

    private func loaded(library: FakeLibrary = FakeLibrary()) async -> BrowseViewModel {
        let model = BrowseViewModel(repository: TreeRepository(), library: library)
        await model.load()
        return model
    }

    @Test("should list the chapters in the installed set")
    func listsChapters() async {
        #expect(await loaded().chapters == ["Endocrine", "Circulatory"])
    }

    @Test("should select the first chapter so the window is never empty")
    func selectsFirstChapter() async {
        #expect(await loaded().selection == .chapter("Endocrine"))
    }

    @Test("should report having a hierarchy when chapters exist")
    func reportsHierarchy() async {
        #expect(await loaded().hasHierarchy)
    }

    @Test("should report no hierarchy for a set imported without the tabular file")
    func reportsMissingHierarchy() async {
        let model = BrowseViewModel(repository: CountingRepository())
        await model.load()
        #expect(model.hasHierarchy == false)
    }

    @Test("should not load a node's children until it is opened")
    func loadsChildrenLazily() async {
        let repository = TreeRepository()
        let model = BrowseViewModel(repository: repository)
        await model.load()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(await repository.childRequests.isEmpty)
    }

    @Test("should load a node's children when it is opened")
    func loadsChildrenOnDemand() async {
        let model = await loaded()
        try? await Task.sleep(for: .milliseconds(50))
        guard let root = model.roots.first else { return }

        await root.loadChildrenIfNeeded()

        #expect(root.children?.map(\.code.code) == ["E11.2"])
    }

    @Test("should not reload children that are already loaded")
    func loadsChildrenOnce() async {
        let repository = TreeRepository()
        let model = BrowseViewModel(repository: repository)
        await model.load()
        try? await Task.sleep(for: .milliseconds(50))
        guard let root = model.roots.first else { return }

        await root.loadChildrenIfNeeded()
        await root.loadChildrenIfNeeded()

        #expect(await repository.childRequests.count == 1)
    }

    @Test("should load the detail for a selected code")
    func loadsDetail() async {
        let model = await loaded()
        model.selectedCode = ClinicalCode(code: "E11", display: "", system: .icd10cm)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.detail?.code.code == "E11")
    }

    @Test("should carry the publisher's notes into the detail")
    func detailCarriesNotes() async {
        let model = await loaded()
        model.selectedCode = ClinicalCode(code: "E11", display: "", system: .icd10cm)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.detail?.notes.first?.kind == .excludes1)
    }

    @Test("should give the full ancestry of a nested code")
    func detailCarriesAncestry() async {
        let model = await loaded()
        model.selectedCode = ClinicalCode(code: "E11.21", display: "", system: .icd10cm)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.detail?.ancestors.map(\.code) == ["E11.2", "E11"])
    }

    @Test("should switch the root list when the chapter changes")
    func switchesChapter() async {
        let model = await loaded()
        model.selection = .chapter("Circulatory")
        await model.pendingWork?.value

        #expect(model.roots.map(\.code.code) == ["I10"])
    }

    // MARK: - Lists

    @Test("should create a list and select it")
    func createsAndSelectsList() async {
        let model = await loaded()

        model.createList(named: "Diabetes clinic")
        await model.pendingWork?.value

        #expect(model.selectedList?.name == "Diabetes clinic")
    }

    @Test("should ignore a list name that is only whitespace")
    func ignoresBlankListName() async {
        let model = await loaded()

        model.createList(named: "   ")
        await model.pendingWork?.value

        #expect(model.lists.isEmpty)
    }

    @Test("should add the selected code to a list")
    func addsSelectedCodeToList() async {
        let model = await loaded()
        model.createList(named: "Clinic")
        await model.pendingWork?.value
        model.selectedCode = ClinicalCode(code: "E11", display: "", system: .icd10cm)
        await model.pendingWork?.value

        model.addSelectedCode(toList: model.lists[0].id)
        await model.pendingWork?.value

        #expect(model.listCodes.map(\.code) == ["E11"])
    }

    @Test("should show a list's codes when it is selected")
    func showsListContents() async {
        let model = await loaded()
        model.createList(named: "Clinic")
        await model.pendingWork?.value
        model.selectedCode = ClinicalCode(code: "E11", display: "", system: .icd10cm)
        await model.pendingWork?.value
        model.addSelectedCode(toList: model.lists[0].id)
        await model.pendingWork?.value

        model.selection = .chapter("Endocrine")
        await model.pendingWork?.value
        model.selection = .list(model.lists[0].id)
        await model.pendingWork?.value

        #expect(model.listCodes.count == 1)
    }

    @Test("should clear the code tree while a list is shown")
    func listHidesTree() async {
        let model = await loaded()
        model.createList(named: "Clinic")
        await model.pendingWork?.value

        #expect(model.roots.isEmpty)
    }

    @Test("should remove the selected code from the list being viewed")
    func removesFromCurrentList() async {
        let model = await loaded()
        model.createList(named: "Clinic")
        await model.pendingWork?.value
        model.selectedCode = ClinicalCode(code: "E11", display: "", system: .icd10cm)
        await model.pendingWork?.value
        model.addSelectedCode(toList: model.lists[0].id)
        await model.pendingWork?.value

        model.removeSelectedCodeFromCurrentList()
        await model.pendingWork?.value

        #expect(model.listCodes.isEmpty)
    }

    @Test("should fall back to a chapter when the selected list is deleted")
    func deletingSelectedListFallsBack() async {
        let model = await loaded()
        model.createList(named: "Clinic")
        await model.pendingWork?.value

        model.deleteList(model.lists[0].id)
        await model.pendingWork?.value

        #expect(model.selection == .chapter("Endocrine"))
    }

    @Test("should report no current list while a chapter is selected")
    func noCurrentListForChapter() async {
        #expect(await loaded().selectedList == nil)
    }
}
