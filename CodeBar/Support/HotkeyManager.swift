import AppKit
import ApplicationServices

/// Literal value of `kAXTrustedCheckOptionPrompt`. The imported C global is a
/// `var`, which Swift 6 rejects as shared mutable state; the underlying string
/// has been stable since macOS 10.9.
private let AX_TRUSTED_CHECK_OPTION_PROMPT = "AXTrustedCheckOptionPrompt"

/// Listens for a global keyboard shortcut (default: Option+Command+C) so the
/// search panel can be summoned from any app, not just by clicking the menu
/// bar icon. Requires Accessibility permission (System Settings > Privacy &
/// Security > Accessibility) — macOS will prompt automatically on first run.
///
/// TODO(yhmiller): phase 3 replaces this with Carbon `RegisterEventHotKey`,
/// which needs no Accessibility permission, works inside the App Sandbox, and
/// consumes the keystroke instead of letting it through to the frontmost app.
/// See docs/ARCHITECTURE.md §5.4.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var monitor: Any?

    /// Called on the main actor when the hotkey is pressed.
    var onTrigger: (@MainActor () -> Void)?

    func start() {
        // Prompts the user to grant Accessibility permission if not already granted.
        let options = [AX_TRUSTED_CHECK_OPTION_PROMPT: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // `event` is deliberately not captured across the hop: NSEvent is
            // not Sendable, and everything needed is read synchronously here.
            guard Self.isTriggerCombination(event) else { return }
            Task { @MainActor in
                HotkeyManager.shared.onTrigger?()
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private nonisolated static func isTriggerCombination(_ event: NSEvent) -> Bool {
        let requiredFlags: NSEvent.ModifierFlags = [.command, .option]
        return event.modifierFlags.intersection(.deviceIndependentFlagsMask) == requiredFlags
            && event.charactersIgnoringModifiers?.lowercased() == "c"
    }
}
