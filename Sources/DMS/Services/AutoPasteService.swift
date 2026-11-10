import Foundation
import AppKit
import CoreGraphics

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

        target.activate(options: .activateIgnoringOtherApps)

        // Give the target app a moment to become frontmost and focus its key window,
        // otherwise the synthetic Cmd+V lands on the clipboard panel itself.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
            keyDown?.flags = .maskCommand
            keyDown?.post(tap: .cgSessionEventTap)

            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
            keyUp?.flags = .maskCommand
            keyUp?.post(tap: .cgSessionEventTap)
        }
        return true
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
