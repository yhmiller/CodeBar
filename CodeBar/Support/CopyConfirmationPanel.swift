import AppKit
import CodeBarUI
import SwiftUI

private let VISIBLE_DURATION = Duration.milliseconds(1200)

private let FADE_IN: TimeInterval = 0.1
private let FADE_OUT: TimeInterval = 0.2
private let BOTTOM_INSET: CGFloat = 140

@MainActor
final class CopyConfirmationPanel {
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?

    func show(_ copiedText: String) {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        AccessibilityNotification.Announcement("Copied \(copiedText)").post()
        dismissal?.cancel()

        let panel = self.panel ?? makePanel()
        panel.contentViewController = NSHostingController(
            rootView: CopyConfirmationView(copiedText: copiedText)
        )
        panel.layoutIfNeeded()
        position(panel)

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
            MainActor.assumeIsolated {
                panel.orderOut(nil)
            }
        }
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

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
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.panel = panel
        return panel
    }
}
