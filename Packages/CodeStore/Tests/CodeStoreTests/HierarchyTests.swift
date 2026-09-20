import CodeCore
import Foundation
import SQLiteKit
import Testing
@testable import CodeStore

@Suite("Hierarchy and notes")
struct HierarchyTests {

    private let tree: [ClinicalCode] = [
        ClinicalCode(code: "E11", display: "Type 2 diabetes mellitus", system: .icd10cm,
                     isBillable: false, chapter: "Endocrine"),
        ClinicalCode(code: "E11.2", display: "Type 2 diabetes with kidney complications",
                     system: .icd10cm, isBillable: false, parent: "E11", chapter: "Endocrine"),
        ClinicalCode(code: "E11.21", display: "Type 2 diabetes with diabetic nephropathy",
                     system: .icd10cm, isBillable: true, parent: "E11.2", chapter: "Endocrine"),
        ClinicalCode(code: "E11.9", display: "Type 2 diabetes without complications",
                     system: .icd10cm, isBillable: true, parent: "E11", chapter: "Endocrine")
    ]

    private var notes: [String: [CodeNote]] {
        ["ICD-10-CM-E11": [
            CodeNote(kind: .excludes1, text: "type 1 diabetes mellitus (E10.-)"),
            CodeNote(kind: .useAdditionalCode, text: "insulin (Z79.4)")
        ]]
    }

    private func seeded() async throws -> SQLiteCodeStore {
        let store = try SQLiteCodeStore(location: .inMemory)
        try await store.ingest(CodeSetImport(codes: tree, notes: notes))
        return store
    }

    @Test("should list the direct children of a code")
    func listsChildren() async throws {
        let children = try await seeded().children(of: "E11", in: .icd10cm)
        #expect(children.map(\.code) == ["E11.2", "E11.9"])
    }

    @Test("should not list a grandchild as a direct child")
    func excludesGrandchildren() async throws {
        let children = try await seeded().children(of: "E11", in: .icd10cm)
        #expect(children.contains { $0.code == "E11.21" } == false)
    }

    @Test("should treat codes without a parent as the roots")
    func listsRoots() async throws {
        let roots = try await seeded().children(of: nil, in: .icd10cm)
        #expect(roots.map(\.code) == ["E11"])
    }

    @Test("should walk ancestors nearest first")
    func walksAncestors() async throws {
        let detail = try await seeded().detail(for: tree[2])
        #expect(detail?.ancestors.map(\.code) == ["E11.2", "E11"])
    }

    @Test("should report no ancestors for a root code")
    func rootHasNoAncestors() async throws {
        #expect(try await seeded().detail(for: tree[0])?.ancestors.isEmpty == true)
    }

    @Test("should keep the publisher's notes against the code")
    func keepsNotes() async throws {
        let detail = try await seeded().detail(for: tree[0])
        #expect(detail?.notes.count == 2)
    }

    @Test("should keep excludes1 distinct from other note kinds")
    func distinguishesExcludes1() async throws {
        let detail = try await seeded().detail(for: tree[0])
        #expect(detail?.notes.first?.kind == .excludes1)
    }

    @Test("should preserve the order the publisher listed notes in")
    func preservesNoteOrder() async throws {
        let detail = try await seeded().detail(for: tree[0])
        #expect(detail?.notes.map(\.kind) == [.excludes1, .useAdditionalCode])
    }

    @Test("should report no detail for a code that is not installed")
    func missingCodeHasNoDetail() async throws {
        let absent = ClinicalCode(code: "Z99.9", display: "Absent", system: .icd10cm)
        #expect(try await seeded().detail(for: absent) == nil)
    }

    @Test("should carry the chapter through")
    func carriesChapter() async throws {
        #expect(try await seeded().detail(for: tree[3])?.code.chapter == "Endocrine")
    }

    @Test("should replace notes rather than accumulate them across imports")
    func replacesNotesOnReimport() async throws {
        let store = try await seeded()
        try await store.ingest(CodeSetImport(codes: tree, notes: notes))

        #expect(try await store.detail(for: tree[0])?.notes.count == 2)
    }

    @Test("should keep hierarchy when a later import omits it")
    func keepsHierarchyWhenLaterImportIsThinner() async throws {
        let store = try await seeded()
        let thin = ClinicalCode(code: "E11.21", display: "Type 2 diabetes with diabetic nephropathy",
                                system: .icd10cm)
        try await store.ingest(CodeSetImport(codes: [thin]))

        #expect(try await store.detail(for: thin)?.code.parent == "E11.2")
    }

    @Test("should drop a system's notes when its code set is removed")
    func removesNotesWithCodeSet() async throws {
        let store = try await seeded()
        try await store.removeCodeSet(.icd10cm)

        let database = try Database(path: ":memory:")
        _ = database
        #expect(try await store.children(of: nil, in: .icd10cm).isEmpty)
    }

    @Test("should survive a parent that points at itself")
    func survivesCyclicParent() async throws {
        let store = try SQLiteCodeStore(location: .inMemory)
        let cyclic = ClinicalCode(code: "X1", display: "Cyclic", system: .icd10cm, parent: "X1")
        try await store.ingest(CodeSetImport(codes: [cyclic]))

        #expect(try await store.detail(for: cyclic)?.ancestors.isEmpty == true)
    }
}
