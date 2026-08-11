import CodeCore
import Foundation
import Testing
@testable import CodePlatform

@Suite("UserDefaultsCodeUsageStore")
@MainActor
struct UserDefaultsCodeUsageStoreTests {

    /// A private defaults domain per test, so nothing touches the real app's.
    private func makeStore() -> (UserDefaultsCodeUsageStore, UserDefaults) {
        let suite = "codebar.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (UserDefaultsCodeUsageStore(defaults: defaults), defaults)
    }

    private let diabetes = ClinicalCode(
        code: "E11.9", display: "Type 2 diabetes mellitus without complications",
        system: .icd10cm, isBillable: true
    )
    private let asthma = ClinicalCode(
        code: "J45.909", display: "Unspecified asthma, uncomplicated",
        system: .icd10cm, isBillable: true
    )

    @Test("should start with nothing pinned")
    func startsEmpty() {
        let (store, _) = makeStore()
        #expect(store.pinnedCodes.isEmpty)
    }

    @Test("should pin a code")
    func pinsACode() {
        let (store, _) = makeStore()
        store.togglePin(diabetes)
        #expect(store.isPinned(diabetes))
    }

    @Test("should unpin a code that was already pinned")
    func unpinsACode() {
        let (store, _) = makeStore()
        store.togglePin(diabetes)
        store.togglePin(diabetes)
        #expect(store.isPinned(diabetes) == false)
    }

    @Test("should put the most recently pinned code first")
    func mostRecentPinFirst() {
        let (store, _) = makeStore()
        store.togglePin(diabetes)
        store.togglePin(asthma)
        #expect(store.pinnedCodes.first?.code == asthma.code)
    }

    @Test("should record a copied code as recent")
    func recordsRecentUse() {
        let (store, _) = makeStore()
        store.recordUse(of: diabetes)
        #expect(store.recentCodes.first?.code == diabetes.code)
    }

    @Test("should not list the same code twice in recents")
    func recentsAreDeduplicated() {
        let (store, _) = makeStore()
        store.recordUse(of: diabetes)
        store.recordUse(of: asthma)
        store.recordUse(of: diabetes)
        #expect(store.recentCodes.count == 2)
    }

    @Test("should move a re-used code back to the front of recents")
    func reuseMovesToFront() {
        let (store, _) = makeStore()
        store.recordUse(of: diabetes)
        store.recordUse(of: asthma)
        store.recordUse(of: diabetes)
        #expect(store.recentCodes.first?.code == diabetes.code)
    }

    @Test("should cap how many recents it remembers")
    func capsRecents() {
        let (store, _) = makeStore()
        for index in 0..<20 {
            store.recordUse(of: ClinicalCode(code: "X\(index)", display: "Code \(index)", system: .icd10cm))
        }
        #expect(store.recentCodes.count == 8)
    }

    @Test("should drop the oldest recent when the cap is reached")
    func dropsOldestRecent() {
        let (store, _) = makeStore()
        for index in 0..<20 {
            store.recordUse(of: ClinicalCode(code: "X\(index)", display: "Code \(index)", system: .icd10cm))
        }
        #expect(store.recentCodes.contains { $0.code == "X0" } == false)
    }

    @Test("should still have the pins after relaunching")
    func pinsSurviveRelaunch() {
        let (store, defaults) = makeStore()
        store.togglePin(diabetes)

        let reopened = UserDefaultsCodeUsageStore(defaults: defaults)

        #expect(reopened.isPinned(diabetes))
    }

    @Test("should still have the recents after relaunching")
    func recentsSurviveRelaunch() {
        let (store, defaults) = makeStore()
        store.recordUse(of: asthma)

        let reopened = UserDefaultsCodeUsageStore(defaults: defaults)

        #expect(reopened.recentCodes.first?.code == asthma.code)
    }

    @Test("should preserve billability through persistence")
    func preservesBillability() {
        let (store, defaults) = makeStore()
        store.togglePin(ClinicalCode(code: "E11", display: "Type 2 diabetes mellitus",
                                     system: .icd10cm, isBillable: false))

        let reopened = UserDefaultsCodeUsageStore(defaults: defaults)

        #expect(reopened.pinnedCodes.first?.isBillable == false)
    }

    @Test("should start empty rather than crash on corrupt stored data")
    func survivesCorruptData() {
        let suite = "codebar.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(Data("not json".utf8), forKey: "CodeBar.pinnedCodes")

        #expect(UserDefaultsCodeUsageStore(defaults: defaults).pinnedCodes.isEmpty)
    }
}
