import AppKit
import ApplicationServices

/// Listens for a global keyboard shortcut (default: Option+Command+C) so the
/// search panel can be summoned from any app, not just by clicking the menu
/// bar icon. Requires Accessibility permission (System Settings > Privacy &
/// Security > Accessibility) — macOS will prompt automatically on first run.
final class HotkeyManager {
    static let shared = HotkeyManager()
    private var monitor: Any?

    /// Called on the main thread when the hotkey is pressed.
    var onTrigger: (() -> Void)?

    func start() {
        // Prompts the user to grant Accessibility permission if not already granted.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            // Option + Command + C
            let requiredFlags: NSEvent.ModifierFlags = [.command, .option]
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == requiredFlags,
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                DispatchQueue.main.async { self.onTrigger?() }
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
