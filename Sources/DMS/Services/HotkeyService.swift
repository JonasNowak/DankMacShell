import AppKit
import Carbon.HIToolbox

/// Global hotkey registration via Carbon HIToolbox (requires no accessibility permissions).
@MainActor
public final class HotkeyService {
    public static let shared = HotkeyService()

    private var references: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var actions: [UInt32: @MainActor () -> Void] = [:]

    private init() {
        setupHandler()
    }

    private func setupHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, context in
            guard let event = event, let context = context else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return noErr }

            let service = Unmanaged<HotkeyService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                service.actions[hotKeyID.id]?()
            }
            return noErr
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        _ = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, context, &handler)
    }

    public func register(id: UInt32 = 1, keyCode: Int = kVK_Space, modifiers: Int = optionKey, action: @escaping @MainActor () -> Void) {
        unregister(id: id)
        self.actions[id] = action

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x444D_5348), id: id) // 'DMSH'
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            references[id] = ref
        }
    }

    public func unregister(id: UInt32) {
        if let ref = references[id] {
            UnregisterEventHotKey(ref)
            references.removeValue(forKey: id)
        }
        actions.removeValue(forKey: id)
    }

    public func unregisterAll() {
        for (_, ref) in references {
            UnregisterEventHotKey(ref)
        }
        references.removeAll()
        actions.removeAll()
    }
}
