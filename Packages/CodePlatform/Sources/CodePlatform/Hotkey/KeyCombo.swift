import Carbon.HIToolbox

/// A global keyboard shortcut, expressed independently of Carbon's bit masks.
///
/// Kept as a value type so making the shortcut configurable is a matter of
/// persisting one of these and re-registering.
public struct KeyCombo: Equatable, Sendable {

    public struct Modifiers: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)
    }

    /// Virtual key code, e.g. `kVK_ANSI_C`. Layout-independent: it identifies the
    /// physical key, not the character it produces.
    public let keyCode: UInt32
    public let modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ⌥⌘C.
    public static let `default` = KeyCombo(
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: [.command, .option]
    )

    // MARK: - Carbon interchange

    /// The modifier mask `RegisterEventHotKey` expects.
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

    /// Menu-style rendering, e.g. `⌥⌘C`. Modifier order follows Apple's
    /// convention: control, option, shift, command.
    public var displayString: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + (Self.keyLabels[keyCode] ?? "?")
    }

    /// Only the keys CodeBar can currently be bound to. This widens when the
    /// shortcut becomes configurable.
    private static let keyLabels: [UInt32: String] = [
        UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_K): "K",
        UInt32(kVK_Space): "Space"
    ]
}
