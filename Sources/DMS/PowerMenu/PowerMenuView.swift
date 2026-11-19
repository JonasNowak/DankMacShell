import SwiftUI
import AppKit
import Darwin
import DMSCore

public struct PowerMenuView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @State private var pendingAction: String?
    public var onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Power & Session")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)

                Text(pendingAction == nil ? "Choose an action" : "Click \"Sure?\" again to confirm")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(pendingAction == nil ? theme.onSurfaceVariant : theme.error)
            }

            HStack(spacing: 16) {
                PowerOptionButton(
                    icon: "lock.fill",
                    label: "Lock",
                    color: theme.primary
                ) {
                    onClose()
                    PowerMenuView.lockScreen()
                }

                PowerOptionButton(
                    icon: "moon.zzz.fill",
                    label: "Sleep",
                    color: theme.secondary
                ) {
                    onClose()
                    PowerMenuView.sleepSystem()
                }

                PowerOptionButton(
                    icon: "arrow.counterclockwise",
                    label: pendingAction == "Restart" ? "Sure?" : "Restart",
                    color: pendingAction == "Restart" ? theme.error : theme.warning
                ) {
                    if pendingAction == "Restart" {
                        pendingAction = nil
                        onClose()
                        PowerMenuView.restartSystem()
                    } else {
                        pendingAction = "Restart"
                    }
                }

                PowerOptionButton(
                    icon: "power",
                    label: pendingAction == "Shut Down" ? "Sure?" : "Shut Down",
                    color: theme.error
                ) {
                    if pendingAction == "Shut Down" {
                        pendingAction = nil
                        onClose()
                        PowerMenuView.shutDownSystem()
                    } else {
                        pendingAction = "Shut Down"
                    }
                }

                PowerOptionButton(
                    icon: "rectangle.portrait.and.arrow.right",
                    label: pendingAction == "Log Out" ? "Sure?" : "Log Out",
                    color: pendingAction == "Log Out" ? theme.error : theme.outline
                ) {
                    if pendingAction == "Log Out" {
                        pendingAction = nil
                        onClose()
                        PowerMenuView.logOut()
                    } else {
                        pendingAction = "Log Out"
                    }
                }
            }

            Button {
                onClose()
            } label: {
                Text("Cancel")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.onSurfaceVariant)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 360)
        .background(GlassSurfaceBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.panelBorderColor, lineWidth: 1)
        )
        .shadow(color: theme.adaptiveShadowColor(baseOpacity: 0.35), radius: 18, x: 0, y: 8)
    }

    public static func executeAppleScript(_ script: String) {
        guard let appleScript = NSAppleScript(source: script) else { return }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
        if let error = error {
            NSLog("PowerMenu AppleScript failed: %@", error)
            Task { @MainActor in
                ToastCenter.shared.show(
                    icon: "exclamationmark.triangle.fill",
                    message: "Automation permission denied — allow DMS in Privacy & Security > Automation"
                )
            }
        }
    }

    /// Locks the screen for real via login.framework's `SACLockScreenImmediate`,
    /// falling back to CGSession `-suspend` and finally `pmset displaysleepnow`.
    public static func lockScreen() {
        if let loginLib = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY) {
            if let sym = dlsym(loginLib, "SACLockScreenImmediate") {
                let lockFn = unsafeBitCast(sym, to: (@convention(c) () -> Void).self)
                lockFn()
                return
            }
        }

        let cgSession = Process()
        cgSession.launchPath = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        cgSession.arguments = ["-suspend"]
        try? cgSession.run()

        let pmset = Process()
        pmset.launchPath = "/usr/bin/pmset"
        pmset.arguments = ["displaysleepnow"]
        try? pmset.run()
    }

    public static func sleepSystem() {
        let pmset = Process()
        pmset.launchPath = "/usr/bin/pmset"
        pmset.arguments = ["sleepnow"]
        try? pmset.run()
    }

    public static func restartSystem() {
        executeAppleScript("tell application \"System Events\" to restart")
    }

    public static func shutDownSystem() {
        executeAppleScript("tell application \"System Events\" to shut down")
    }

    public static func logOut() {
        executeAppleScript("tell application \"System Events\" to log out")
    }
}

public struct PowerOptionButton: View {
    public let icon: String
    public let label: String
    public let color: Color
    public let action: () -> Void

    @ObservedObject private var theme = ThemeStore.shared
    @State private var isHovered = false

    public var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(isHovered ? color.opacity(0.2) : theme.surfaceContainerHigh)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(color.opacity(0.4), lineWidth: 1)
                    )

                Text(label)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)
            }
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
    }
}
