import Carbon.HIToolbox
import Foundation

public struct KeyCombo: Equatable, Sendable, Codable {

    public struct Modifiers: OptionSet, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)
    }

    public let keyCode: UInt32
    public let modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let `default` = KeyCombo(
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: [.command, .option]
    )

    // MARK: - Carbon interchange

    public var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if modifiers.contains(.command) { mask |= UInt32(cmdKey) }
        if modifiers.contains(.option) { mask |= UInt32(optionKey) }
        if modifiers.contains(.control) { mask |= UInt32(controlKey) }
        if modifiers.contains(.shift) { mask |= UInt32(shiftKey) }
        return mask
    }

    public init(keyCode: UInt32, carbonModifiers mask: UInt32) {
        var modifiers: Modifiers = []
        if mask & UInt32(cmdKey) != 0 { modifiers.insert(.command) }
        if mask & UInt32(optionKey) != 0 { modifiers.insert(.option) }
        if mask & UInt32(controlKey) != 0 { modifiers.insert(.control) }
        if mask & UInt32(shiftKey) != 0 { modifiers.insert(.shift) }
        self.init(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - Display

    public var displayString: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + Self.keyLabel(for: keyCode)
    }

    public var keycapTokens: [String] {
        var tokens: [String] = []
        if modifiers.contains(.control) { tokens.append("⌃") }
        if modifiers.contains(.option) { tokens.append("⌥") }
        if modifiers.contains(.shift) { tokens.append("⇧") }
        if modifiers.contains(.command) { tokens.append("⌘") }
        tokens.append(Self.keyLabel(for: keyCode))
        return tokens
    }

    public var isFunctionKey: Bool {
        let fKeys: Set<UInt32> = [
            UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
            UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
            UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12)
        ]
        return fKeys.contains(keyCode)
    }

    public var isValidHotkey: Bool {
        if isFunctionKey { return true }
        return modifiers.contains(.command) || modifiers.contains(.option) || modifiers.contains(.control)
    }

    public static func keyLabel(for keyCode: UInt32) -> String {
        if let label = keyLabels[keyCode] {
            return label
        }

        // Fallback: translate keycode using current keyboard layout
        if let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
           let layoutDataRef = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) {
            let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self)
            let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
            var keysDown: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var realLength: Int = 0
            let status = UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &keysDown,
                4,
                &realLength,
                &chars
            )
            if status == noErr && realLength > 0 {
                return String(utf16CodeUnits: chars, count: realLength).uppercased()
            }
        }
        return "?"
    }

    // MARK: - Persistence

    public static func load(from defaults: UserDefaults = .standard) -> KeyCombo {
        guard defaults.object(forKey: "CodeBar.hotkeyKeyCode") != nil,
              defaults.object(forKey: "CodeBar.hotkeyCarbonModifiers") != nil else {
            return .default
        }
        let keyCode = UInt32(defaults.integer(forKey: "CodeBar.hotkeyKeyCode"))
        let mask = UInt32(defaults.integer(forKey: "CodeBar.hotkeyCarbonModifiers"))
        let combo = KeyCombo(keyCode: keyCode, carbonModifiers: mask)
        return combo.isValidHotkey ? combo : .default
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(Int(keyCode), forKey: "CodeBar.hotkeyKeyCode")
        defaults.set(Int(carbonModifiers), forKey: "CodeBar.hotkeyCarbonModifiers")
    }

    // MARK: - Static key mappings

    private static let keyLabels: [UInt32: String] = [
        // Letters
        UInt32(kVK_ANSI_A): "A",
        UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E",
        UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G",
        UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K",
        UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M",
        UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q",
        UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S",
        UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W",
        UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y",
        UInt32(kVK_ANSI_Z): "Z",

        // Numbers
        UInt32(kVK_ANSI_0): "0",
        UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4",
        UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6",
        UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",

        // Function Keys
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12",

        // Navigation & Special
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "↵",
        UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Escape): "⎋",
        UInt32(kVK_Delete): "⌫",
        UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",

        // Punctuation & Symbols
        UInt32(kVK_ANSI_Minus): "-",
        UInt32(kVK_ANSI_Equal): "=",
        UInt32(kVK_ANSI_LeftBracket): "[",
        UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Backslash): "\\",
        UInt32(kVK_ANSI_Semicolon): ";",
        UInt32(kVK_ANSI_Quote): "'",
        UInt32(kVK_ANSI_Comma): ",",
        UInt32(kVK_ANSI_Period): ".",
        UInt32(kVK_ANSI_Slash): "/",
        UInt32(kVK_ANSI_Grave): "`"
    ]
}
