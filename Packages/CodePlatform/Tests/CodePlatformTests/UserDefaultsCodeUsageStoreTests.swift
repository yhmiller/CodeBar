import CodeCore
import Foundation
import Testing
@testable import CodePlatform

@Suite("Legacy UserDefaults usage store")
@MainActor
struct LegacyUserDefaultsUsageStoreTests {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "codebar.tests.\(UUID().uuidString)")!
    }

    private let diabetes = ClinicalCode(
        code: "E11.9", display: "Type 2 diabetes mellitus without complications",
        system: .icd10cm, isBillable: true
    )

    private func write(_ codes: [ClinicalCode], key: String, to defaults: UserDefaults) {
        defaults.set(try! JSONEncoder().encode(codes), forKey: key)
    }

    @Test("should read pins written by an older version")
    func readsLegacyPins() {
        let defaults = makeDefaults()
        write([diabetes], key: "CodeBar.pinnedCodes", to: defaults)

        #expect(LegacyUserDefaultsUsageStore(defaults: defaults).pinnedCodes.count == 1)
    }

    @Test("should read recents written by an older version")
    func readsLegacyRecents() {
        let defaults = makeDefaults()
        write([diabetes], key: "CodeBar.recentCodes", to: defaults)

        #expect(LegacyUserDefaultsUsageStore(defaults: defaults).recentCodes.count == 1)
    }

    @Test("should preserve billability when reading legacy data")
    func preservesBillability() {
        let defaults = makeDefaults()
        write([ClinicalCode(code: "E11", display: "Type 2 diabetes mellitus",
                            system: .icd10cm, isBillable: false)],
              key: "CodeBar.pinnedCodes", to: defaults)

        #expect(LegacyUserDefaultsUsageStore(defaults: defaults).pinnedCodes.first?.isBillable == false)
    }

    @Test("should report nothing rather than crash on corrupt stored data")
    func survivesCorruptData() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "CodeBar.pinnedCodes")

        #expect(LegacyUserDefaultsUsageStore(defaults: defaults).pinnedCodes.isEmpty)
    }

    @Test("should forget everything once cleared")
    func clearsAfterHandover() {
        let defaults = makeDefaults()
        write([diabetes], key: "CodeBar.pinnedCodes", to: defaults)
        let store = LegacyUserDefaultsUsageStore(defaults: defaults)

        store.clear()

        #expect(LegacyUserDefaultsUsageStore(defaults: defaults).pinnedCodes.isEmpty)
    }
}
