import Foundation
import AppKit
import CoreGraphics
import Carbon

/// Synthetic Cmd+V auto-paste into the previously focused app (ROADMAP v0.6 CLIP, spec 26 §2).
///
/// Flow: `ClipboardController.show()` calls `capturePreviousApp()` *before* activating the
/// clipboard panel, so we remember which app had focus. When the user presses Return on a
/// history item, `pasteIntoPreviousApp()` re-activates that app and posts a synthetic
/// Cmd+V (virtual key 0x09 with `.maskCommand`) at the session event tap.
///
/// Posting synthetic input requires the **Accessibility** permission
/// (`AXIsProcessTrustedWithOptions`); without it the paste is skipped and a toast points
/// the user at System Settings.
@MainActor
public final class AutoPasteService: ObservableObject {
    public static let shared = AutoPasteService()

    /// The app that was frontmost before the clipboard panel took focus.
    private var previousApp: NSRunningApplication?

    private init() {}

    /// True when synthetic key events can be posted (Accessibility permission granted).
    public var canPostKeyEvents: Bool {
        let opts = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Records the currently frontmost app as the auto-paste target.
    /// Call this before the clipboard panel becomes key/active.
    public func capturePreviousApp() {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != NSRunningApplication.current.processIdentifier {
            previousApp = frontmost
        }
    }

    /// Re-activates the previously focused app and posts a synthetic Cmd+V.
    /// Returns false when there is no target or Accessibility permission is missing.
    @discardableResult
    public func pasteIntoPreviousApp() -> Bool {
        guard let target = previousApp else { return false }
        guard canPostKeyEvents else {
            ToastCenter.shared.show(
                icon: "hand.raised.fill",
                message: "Grant Accessibility access in System Settings to auto-paste"
            )
            openAccessibilitySettings()
            return false
        }

        target.activate()

        // Give the target app a moment to become frontmost and focus its key window,
        // otherwise the synthetic Cmd+V lands on the clipboard panel itself.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Only post when the target really is frontmost now — otherwise the
            // synthetic Cmd+V would land on whatever app currently has focus.
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
                return
            }
            let keyCode = Self.virtualKeyCodeForV()
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
            keyDown?.flags = .maskCommand
            keyDown?.post(tap: .cgSessionEventTap)

            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
            keyUp?.flags = .maskCommand
            keyUp?.post(tap: .cgSessionEventTap)
        }
        return true
    }

    /// Virtual keycode of the `'v'` key in the *current* keyboard layout (0x09 on QWERTY).
    /// On Dvorak/Colemak the physical 0x09 key produces a different character, so posting
    /// a hardcoded 0x09 would send the wrong shortcut — resolve it through `UCKeyTranslate`.
    static func virtualKeyCodeForV(fallback: CGKeyCode = 0x09) -> CGKeyCode {
        guard let unmanaged = TISCopyCurrentKeyboardLayoutInputSource() else { return fallback }
        let source = unmanaged.takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return fallback
        }
        let cfData = unsafeBitCast(layoutData, to: CFData.self)
        guard let rawBytes = CFDataGetBytePtr(cfData) else { return fallback }
        return rawBytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layoutPtr in
            var deadKeyState: UInt32 = 0
            var actualLength = 0
            var output = [UniChar](repeating: 0, count: 8)
            for keyCode in UInt16(0)..<128 {
                deadKeyState = 0
                actualLength = 0
                let status = UCKeyTranslate(
                    layoutPtr,
                    keyCode,
                    UInt16(kUCKeyActionDown),
                    0,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysMask),
                    &deadKeyState,
                    output.count,
                    &actualLength,
                    &output
                )
                guard status == 0, actualLength > 0 else { continue }
                let produced = String(utf16CodeUnits: output, count: actualLength)
                if produced.lowercased() == "v" {
                    return CGKeyCode(keyCode)
                }
            }
            return fallback
        }
    }

    private func openAccessibilitySettings() {
        let modernURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")
        let legacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let modernURL, NSWorkspace.shared.open(modernURL) {
            return
        }
        if let legacyURL {
            NSWorkspace.shared.open(legacyURL)
        }
    }
}
