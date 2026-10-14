import AppKit
import SwiftUI
import Carbon.HIToolbox
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

        // Start Unix domain socket server for `dms` CLI and scripts
        IPCSocketServer.shared.start()

        // Show DankBar
        DankBarController.shared.show()
        _ = WorkspaceService.shared
        _ = PluginService.shared
        _ = ToastController.shared
        _ = OSDController.shared
        _ = ClipboardService.shared
        _ = NowPlayingService.shared
        _ = WeatherService.shared

        print("DankMaterialShell for macOS started successfully.")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        IPCSocketServer.shared.stop()
        HotkeyService.shared.unregisterAll()
    }

    private func setupHotkeys() {
        let config = ConfigStore.shared.config

        // ⌥Space: Spotlight Launcher
        if config.launcherHotkey {
            HotkeyService.shared.register(id: 1, keyCode: kVK_Space, modifiers: optionKey) {
                LauncherController.shared.toggle()
            }
        }

        // ⌥D: DankDash Overview
        if config.dashHotkey {
            HotkeyService.shared.register(id: 2, keyCode: kVK_ANSI_D, modifiers: optionKey) {
                DashController.shared.toggle()
            }
        }

        // ⌥N: Notepad Scratchpad
        if config.notepadHotkey {
            HotkeyService.shared.register(id: 3, keyCode: kVK_ANSI_N, modifiers: optionKey) {
                NotepadController.shared.toggle()
            }
        }

        // ⌥V: Clipboard History
        if config.clipboardHotkey {
            HotkeyService.shared.register(id: 4, keyCode: kVK_ANSI_V, modifiers: optionKey) {
                ClipboardController.shared.toggle()
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

        _ = IPCCommandExecutor.execute(command)
    }
}
