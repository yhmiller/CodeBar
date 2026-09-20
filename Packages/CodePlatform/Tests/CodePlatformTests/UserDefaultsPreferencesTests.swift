import Foundation
import Testing
@testable import CodePlatform

@Suite("Dock icon preference")
@MainActor
struct UserDefaultsPreferencesTests {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "codebar.tests.\(UUID().uuidString)")!
    }

    @Test("should show the Dock icon when nothing has been chosen")
    func defaultsToShown() {
        #expect(UserDefaultsPreferences(defaults: makeDefaults()).showsDockIcon)
    }

    @Test("should keep the Dock icon hidden when that was chosen")
    func honoursExplicitOff() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: "CodeBar.showsDockIcon")

        #expect(UserDefaultsPreferences(defaults: defaults).showsDockIcon == false)
    }

    @Test("should persist a change to the Dock icon preference")
    func persistsChange() {
        let defaults = makeDefaults()
        let preferences = UserDefaultsPreferences(defaults: defaults)

        preferences.showsDockIcon = false

        #expect(UserDefaultsPreferences(defaults: defaults).showsDockIcon == false)
    }
}
