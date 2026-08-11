import AppKit
import Carbon.HIToolbox

/// Four-character signature identifying CodeBar's registration to Carbon: 'CBAR'.
private let HOTKEY_SIGNATURE: OSType = 0x4342_4152
private let HOTKEY_ID: UInt32 = 1

/// Registers a system-wide hotkey through Carbon's `RegisterEventHotKey`.
///
/// This replaces `NSEvent.addGlobalMonitorForEvents`, which was the wrong API for
/// the job in four ways: it needed Accessibility permission, it forced the app
/// out of the sandbox, it observed *every* keystroke system-wide, and it did not
/// consume the event — so ⌥⌘C also reached whatever app was in front.
///
/// It also failed silently. Without Accessibility permission the monitor simply
/// never fires, with no error to report, which is why the shortcut appeared to do
/// nothing at all. `RegisterEventHotKey` returns a status code, so a failure here
/// is something we can actually surface.
@MainActor
public final class CarbonHotkeyRegistrar {

    public enum RegistrationError: Error, CustomStringConvertible {
        case handlerInstallFailed(OSStatus)
        /// Most commonly `eventHotKeyExistsErr` — another app already owns the combo.
        case hotkeyRegistrationFailed(OSStatus)

        public var description: String {
            switch self {
            case .handlerInstallFailed(let status):
                "Could not install the hotkey event handler (OSStatus \(status))."
            case .hotkeyRegistrationFailed(let status) where status == OSStatus(eventHotKeyExistsErr):
                "That shortcut is already claimed by another application."
            case .hotkeyRegistrationFailed(let status):
                "Could not register the hotkey (OSStatus \(status))."
            }
        }
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var onTrigger: (@MainActor () -> Void)?

    public init() {}

    /// Registers `combo`, replacing any previous registration.
    ///
    /// Callers must call `unregister()` before releasing the registrar: cleanup
    /// cannot happen in `deinit`, which is not main-actor isolated.
    public func register(_ combo: KeyCombo, onTrigger: @escaping @MainActor () -> Void) throws {
        unregister()
        self.onTrigger = onTrigger

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            self.onTrigger = nil
            throw RegistrationError.handlerInstallFailed(installStatus)
        }

        var hotKeyID = EventHotKeyID(signature: HOTKEY_SIGNATURE, id: HOTKEY_ID)
        let registerStatus = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            unregister()
            throw RegistrationError.hotkeyRegistrationFailed(registerStatus)
        }
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        eventHandlerRef = nil
        onTrigger = nil
    }

    fileprivate func handleHotkeyPressed() {
        onTrigger?()
    }
}

/// Carbon delivers hot-key events on the main thread's run loop, which is what
/// makes `assumeIsolated` sound here.
private func hotkeyEventHandler(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ context: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let context else { return OSStatus(eventNotHandledErr) }
    let registrar = Unmanaged<CarbonHotkeyRegistrar>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated {
        registrar.handleHotkeyPressed()
    }
    return noErr
}
