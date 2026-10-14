import AppKit
import SwiftUI
import DMSCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce single instance
        let runningInstances = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.jonasnowak.dms"
        )
        if runningInstances.count > 1 {
            let others = runningInstances.filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            if !others.isEmpty {
                print("DMS is already running. Exiting duplicate instance.")
                NSApp.terminate(nil)
                return
            }
        }

        setupURLSchemeHandler()
        setupHotkeys()

        // Show DankBar
        DankBarController.shared.show()
        _ = ToastController.shared
        _ = OSDController.shared

        print("DankMaterialShell for macOS started successfully.")
    }

    private func setupHotkeys() {
        if ConfigStore.shared.config.launcherHotkey {
            HotkeyService.shared.register {
                LauncherController.shared.toggle()
            }
        }
    }

    private func setupURLSchemeHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(event:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURL(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              let command = IPCCommand.parse(url: url) else {
            return
        }

        switch command {
        case .toggleLauncher:
            LauncherController.shared.toggle()
        case .openLauncher:
            LauncherController.shared.show()
        case .closeLauncher:
            LauncherController.shared.hide()
        case .toggleControlCenter:
            ControlCenterController.shared.toggle()
        case .openControlCenter:
            ControlCenterController.shared.show()
        case .closeControlCenter:
            ControlCenterController.shared.hide()
        case .powerMenu:
            PowerMenuController.shared.show()
        case .setTheme(let name):
            ThemeStore.shared.apply(theme: name, lightMode: ThemeStore.shared.isLightMode)
            ConfigStore.shared.update { $0.theme = name }
            ToastCenter.shared.show(icon: "paintpalette.fill", message: "Theme switched to \(name.capitalized)")
        case .toggleThemeMode:
            ThemeStore.shared.toggleLightMode()
            ConfigStore.shared.update { $0.isLightMode = ThemeStore.shared.isLightMode }
            ToastCenter.shared.show(
                icon: ThemeStore.shared.isLightMode ? "sun.max.fill" : "moon.fill",
                message: "Switched to \(ThemeStore.shared.isLightMode ? "Light" : "Dark") Mode"
            )
        case .screenshot:
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c"]
            task.launch()
        case .reloadConfig:
            ConfigStore.shared.loadConfig()
            ThemeStore.shared.apply(theme: ConfigStore.shared.config.theme, lightMode: ConfigStore.shared.config.isLightMode)
            ToastCenter.shared.show(icon: "arrow.clockwise", message: "Configuration reloaded")
        case .unknown(let cmd):
            print("Unknown DMS command: \(cmd)")
        }
    }
}
