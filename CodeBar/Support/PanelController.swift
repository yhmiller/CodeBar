import AppKit
import SwiftUI

/// NSPanel subclass that overrides canBecomeKey. Without this, a
/// .nonactivatingPanel style window won't reliably accept keyboard focus,
/// which would make the search field untypeable.
private final class FocusablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Owns the floating, Spotlight-style search panel: creates it lazily,
/// centers it, and toggles visibility from the global hotkey or the menu.
final class SearchPanelController {
    static let shared = SearchPanelController()
    private var panel: NSPanel?

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        show()
    }

    func show() {
        let existingPanel = panel
        let contentView = SearchPanelView(onDismiss: { [weak self] in
            self?.panel?.orderOut(nil)
        })
        let hosting = NSHostingView(rootView: contentView)

        let panel = existingPanel ?? FocusablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.standardWindowButtons.forEach { $0?.isHidden = true }
        panel.contentView = hosting
        panel.center()

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

private extension NSWindow {
    var standardWindowButtons: [NSButton?] {
        [
            standardWindowButton(.closeButton),
            standardWindowButton(.miniaturizeButton),
            standardWindowButton(.zoomButton)
        ]
    }
}
