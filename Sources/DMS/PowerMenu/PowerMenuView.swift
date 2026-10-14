import SwiftUI
import AppKit
import DMSCore

public struct PowerMenuView: View {
    @ObservedObject private var theme = ThemeStore.shared
    public var onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Power & Session")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)

                Text("Choose an action")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(theme.onSurfaceVariant)
            }

            HStack(spacing: 16) {
                PowerOptionButton(
                    icon: "lock.fill",
                    label: "Lock",
                    color: theme.primary
                ) {
                    onClose()
                    Process.launchedProcess(launchPath: "/usr/bin/pmset", arguments: ["displaysleepnow"])
                }

                PowerOptionButton(
                    icon: "moon.zzz.fill",
                    label: "Sleep",
                    color: theme.secondary
                ) {
                    onClose()
                    Process.launchedProcess(launchPath: "/usr/bin/pmset", arguments: ["sleepnow"])
                }

                PowerOptionButton(
                    icon: "arrow.counterclockwise",
                    label: "Restart",
                    color: theme.warning
                ) {
                    onClose()
                    executeAppleScript("tell application \"System Events\" to restart")
                }

                PowerOptionButton(
                    icon: "power",
                    label: "Shut Down",
                    color: Color.red
                ) {
                    onClose()
                    executeAppleScript("tell application \"System Events\" to shut down")
                }

                PowerOptionButton(
                    icon: "rectangle.portrait.and.arrow.right",
                    label: "Log Out",
                    color: theme.outline
                ) {
                    onClose()
                    executeAppleScript("tell application \"System Events\" to log out")
                }
            }

            Button {
                onClose()
            } label: {
                Text("Cancel")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.onSurfaceVariant)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 440)
        .background(theme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.outlineVariant.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 25, x: 0, y: 10)
    }

    private func executeAppleScript(_ script: String) {
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
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
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 52, height: 52)
                    .background(isHovered ? color.opacity(0.2) : theme.surfaceContainerHigh)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(color.opacity(0.4), lineWidth: 1)
                    )

                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)
            }
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
    }
}
