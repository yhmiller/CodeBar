import Carbon.HIToolbox
import Testing
@testable import CodePlatform

@Suite("KeyCombo")
struct KeyComboTests {

    @Test("should map command to the Carbon command bit")
    func mapsCommand() {
        #expect(KeyCombo(keyCode: 0, modifiers: .command).carbonModifiers == UInt32(cmdKey))
    }

    @Test("should map option to the Carbon option bit")
    func mapsOption() {
        #expect(KeyCombo(keyCode: 0, modifiers: .option).carbonModifiers == UInt32(optionKey))
    }

    @Test("should map control to the Carbon control bit")
    func mapsControl() {
        #expect(KeyCombo(keyCode: 0, modifiers: .control).carbonModifiers == UInt32(controlKey))
    }

    @Test("should map shift to the Carbon shift bit")
    func mapsShift() {
        #expect(KeyCombo(keyCode: 0, modifiers: .shift).carbonModifiers == UInt32(shiftKey))
    }

    @Test("should combine multiple modifiers into one mask")
    func combinesModifiers() {
        let combo = KeyCombo(keyCode: 0, modifiers: [.command, .option])

        #expect(combo.carbonModifiers == UInt32(cmdKey) | UInt32(optionKey))
    }

    @Test("should produce an empty mask when there are no modifiers")
    func emptyMaskWithoutModifiers() {
        #expect(KeyCombo(keyCode: 0, modifiers: []).carbonModifiers == 0)
    }

    @Test("should round-trip every modifier through the Carbon mask")
    func roundTripsAllModifiers() {
        let combo = KeyCombo(keyCode: 40, modifiers: [.command, .option, .control, .shift])

        let restored = KeyCombo(keyCode: combo.keyCode, carbonModifiers: combo.carbonModifiers)

        #expect(restored == combo)
    }

    @Test("should round-trip a partial modifier set through the Carbon mask")
    func roundTripsPartialModifiers() {
        let combo = KeyCombo.default

        let restored = KeyCombo(keyCode: combo.keyCode, carbonModifiers: combo.carbonModifiers)

        #expect(restored == combo)
    }

    @Test("should default to the C key")
    func defaultUsesCKey() {
        #expect(KeyCombo.default.keyCode == UInt32(kVK_ANSI_C))
    }

    @Test("should default to command and option")
    func defaultUsesCommandOption() {
        #expect(KeyCombo.default.modifiers == [.command, .option])
    }

    @Test("should render the default combo as its menu shortcut")
    func rendersDefaultDisplayString() {
        #expect(KeyCombo.default.displayString == "⌥⌘C")
    }

    @Test("should order modifiers by Apple's convention when rendering")
    func ordersModifiersForDisplay() {
        let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifiers: [.command, .option, .control, .shift])

        #expect(combo.displayString == "⌃⌥⇧⌘C")
    }

    @Test("should generate keycap tokens array")
    func generatesKeycapTokens() {
        let combo = KeyCombo(keyCode: UInt32(kVK_Space), modifiers: [.option])
        #expect(combo.keycapTokens == ["⌥", "Space"])
        #expect(KeyCombo.default.keycapTokens == ["⌥", "⌘", "C"])
    }

    @Test("should map letters, numbers, and function keys")
    func mapsKeyLabels() {
        #expect(KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: .command).displayString == "⌘A")
        #expect(KeyCombo(keyCode: UInt32(kVK_ANSI_0), modifiers: .command).displayString == "⌘0")
        #expect(KeyCombo(keyCode: UInt32(kVK_F1), modifiers: []).displayString == "F1")
        #expect(KeyCombo(keyCode: UInt32(kVK_Space), modifiers: .option).displayString == "⌥Space")
    }

    @Test("should validate hotkeys correctly")
    func validatesHotkeys() {
        // Function keys are valid without modifiers
        #expect(KeyCombo(keyCode: UInt32(kVK_F1), modifiers: []).isValidHotkey)
        #expect(KeyCombo(keyCode: UInt32(kVK_F12), modifiers: [.shift]).isValidHotkey)

        // Standard keys require Command, Option, or Control
        #expect(!KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: []).isValidHotkey)
        #expect(!KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: [.shift]).isValidHotkey)
        #expect(KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: [.command]).isValidHotkey)
        #expect(KeyCombo(keyCode: UInt32(kVK_Space), modifiers: [.option]).isValidHotkey)
        #expect(KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifiers: [.control]).isValidHotkey)
    }

    @Test("should persist and restore hotkey through UserDefaults")
    func persistsThroughUserDefaults() {
        let defaults = UserDefaults(suiteName: "CodePlatformTestDefaults-\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        #expect(KeyCombo.load(from: defaults) == KeyCombo.default)

        let custom = KeyCombo(keyCode: UInt32(kVK_Space), modifiers: [.option])
        custom.save(to: defaults)

        #expect(KeyCombo.load(from: defaults) == custom)
    }
}
