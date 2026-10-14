import AppKit
import Carbon.HIToolbox

/// Global hotkey registration via Carbon HIToolbox (requires no accessibility permissions).
@MainActor
public final class HotkeyService {
    public static let shared = HotkeyService()

    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var action: (@MainActor () -> Void)?

    private init() {}

    public func register(keyCode: Int = kVK_Space, modifiers: Int = optionKey, action: @escaping @MainActor () -> Void) {
        unregister()
        self.action = action

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, _, context in
            guard let context else { return noErr }
            let service = Unmanaged<HotkeyService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                service.action?()
            }
            return noErr
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, context, &handler) == noErr else {
            return
        }

        let id = EventHotKeyID(signature: OSType(0x444D_5348), id: 1) // 'DMSH'
        _ = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            id,
            GetApplicationEventTarget(),
            0,
            &reference
        )
    }

    public func unregister() {
        if let reference {
            UnregisterEventHotKey(reference)
        }
        if let handler {
            RemoveEventHandler(handler)
        }
        reference = nil
        handler = nil
    }
}
