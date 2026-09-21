import AppKit
import SwiftUI

public struct HotkeyRecordingError: LocalizedError, Equatable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// An interactive macOS shortcut recorder that displays keycaps when idle
/// and captures keystrokes when clicked.
public struct ShortcutRecorderView: View {
    public let tokens: [String]
    public let isDefault: Bool
    public let onRecord: (UInt32, UInt32) -> Result<Void, HotkeyRecordingError>
    public let onReset: () -> Void

    @State private var isRecording = false
    @State private var errorMessage: String?
    @State private var eventMonitor: Any?

    public init(
        tokens: [String],
        isDefault: Bool = true,
        onRecord: @escaping (UInt32, UInt32) -> Result<Void, HotkeyRecordingError>,
        onReset: @escaping () -> Void
    ) {
        self.tokens = tokens
        self.isDefault = isDefault
        self.onRecord = onRecord
        self.onReset = onReset
    }

    public var body: some View {
        HStack(spacing: Metric.s) {
            if isRecording {
                recordingBadge
            } else {
                idleButton
            }

            if !isDefault && !isRecording {
                Button(action: {
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                    onReset()
                }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default (⌥⌘C)")
                .accessibilityLabel("Reset to default shortcut")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(Color.warning)
                    .transition(.opacity)
            }
        }
        .onDisappear { stopRecording() }
    }

    private var idleButton: some View {
        Button(action: startRecording) {
            KeycapGroup(keys: tokens)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to record a new shortcut")
        .accessibilityLabel("Shortcut: \(tokens.joined()). Click to record new shortcut.")
    }

    private var recordingBadge: some View {
        HStack(spacing: Metric.xs) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)

            Text("Press shortcut…")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, Metric.s)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: Metric.keycapRadius, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: Metric.keycapRadius, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1)
                )
        )
        .shadow(color: Color.accentColor.opacity(0.2), radius: 3)
    }

    private func startRecording() {
        isRecording = true
        errorMessage = nil
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)

        stopRecording()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            handleKeyEvent(event)
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard isRecording else { return event }

        // Escape cancels recording
        if event.keyCode == 53 {
            stopRecording()
            return nil
        }

        // Delete / Backspace resets to default
        if event.keyCode == 51 {
            onReset()
            stopRecording()
            return nil
        }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        var carbonMask: UInt32 = 0
        if flags.contains(.command) { carbonMask |= 1 << 8 }  // cmdKey in Carbon
        if flags.contains(.option) { carbonMask |= 1 << 11 }  // optionKey in Carbon
        if flags.contains(.control) { carbonMask |= 1 << 12 } // controlKey in Carbon
        if flags.contains(.shift) { carbonMask |= 1 << 9 }    // shiftKey in Carbon

        let keyCode = UInt32(event.keyCode)

        // Function keys F1-F12 are valid alone; others require at least Cmd, Opt, or Ctrl
        let isFKey = (122...133).contains(keyCode) || (96...101).contains(keyCode)
        let hasModifier = flags.contains(.command) || flags.contains(.option) || flags.contains(.control)

        guard isFKey || hasModifier else {
            errorMessage = "Include ⌘, ⌥, or ⌃"
            return nil
        }

        let result = onRecord(keyCode, carbonMask)
        switch result {
        case .success:
            errorMessage = nil
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            stopRecording()
        case .failure(let error):
            errorMessage = error.message
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        }

        return nil
    }
}
