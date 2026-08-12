import Foundation
import Testing
@testable import CodePlatform

/// The Dock icon preference is the one whose default changed meaning.
///
/// It defaulted to off while CodeBar was panel-only. Now that opening the app
/// opens a window, off would mean opening CodeBar shows nothing at all — so the
/// unset case has to read as on, without trampling anyone who chose off.
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

    /// `bool(forKey:)` also returns false here, so this is the assertion that
    /// distinguishes a working default from one that reads every unset install
    /// as an explicit "off".
    ///
    /// The key is spelled out rather than shared with the implementation: it is
    /// the name already on disk in every existing install, so renaming it would
    /// silently discard the user's choice, and a test reusing the constant would
    /// follow the rename instead of catching it.
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
