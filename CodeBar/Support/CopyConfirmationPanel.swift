import AppKit
import CodeBarUI
import SwiftUI

/// How long the confirmation stays up. Long enough to read a code, short enough
/// that it is gone before the user's attention returns to it.
private let VISIBLE_DURATION = Duration.milliseconds(1200)

private let FADE_IN: TimeInterval = 0.1
private let FADE_OUT: TimeInterval = 0.2

/// Distance from the bottom of the screen. Well clear of the Dock and of the
/// search panel's own placement, which sits high.
private let BOTTOM_INSET: CGFloat = 140

/// A borderless window that says what reached the pasteboard.
///
/// Its own window rather than content inside the search panel, because the
/// panel's promise is to get out of the way: an in-panel confirmation would mean
/// holding the panel open for a second after Return, which contradicts the
/// two-second path the whole app is built around. This outlives the panel
/// instead of delaying it.
@MainActor
final class CopyConfirmationPanel {
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?

    func show(_ copiedText: String) {
        // A second copy replaces the first rather than queueing behind it —
        // otherwise a fast user reads a confirmation for the code before last.
        dismissal?.cancel()

        let panel = self.panel ?? makePanel()
        panel.contentViewController = NSHostingController(
            rootView: CopyConfirmationView(copiedText: copiedText)
        )
        panel.layoutIfNeeded()
        position(panel)

        // `orderFrontRegardless` rather than `makeKeyAndOrderFront`: this must
        // never take focus from whatever the user is about to paste into.
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : FADE_IN
            panel.animator().alphaValue = 1
        }

        dismissal = Task { [weak self] in
            try? await Task.sleep(for: VISIBLE_DURATION)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    private func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : FADE_OUT
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Centred on the display under the pointer — the same reasoning as the
    /// search panel's own placement, and the display the user is looking at.
    private func position(_ panel: NSPanel) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? .main
        guard let visible = screen?.visibleFrame else { return }

        let size = panel.frame.size
        panel.setFrameOrigin(
            NSPoint(x: visible.midX - size.width / 2, y: visible.minY + BOTTOM_INSET)
        )
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        // Nothing here is clickable, and swallowing a click would steal it from
        // the app the user has already moved on to.
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.panel = panel
        return panel
    }
}
