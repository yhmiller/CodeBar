import AppKit
import Carbon.HIToolbox

private let HOTKEY_SIGNATURE: OSType = 0x4342_4152
private let HOTKEY_ID: UInt32 = 1

@MainActor
public final class CarbonHotkeyRegistrar {

    public enum RegistrationError: Error, CustomStringConvertible {
        case handlerInstallFailed(OSStatus)
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
