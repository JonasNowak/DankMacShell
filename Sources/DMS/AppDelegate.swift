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
        setupSignalHandlers()

        // Start Unix domain socket server for `dms` CLI and scripts
        IPCSocketServer.shared.start()

        // Restore persistent theme and settings
        let cfg = ConfigStore.shared.config
        ThemeStore.shared.sync(with: cfg)
        if cfg.theme.lowercased() == "dynamic" {
            ThemeStore.shared.setDynamicWallpaper()
        }
        if cfg.getSetting("sleepInhibitEnabled")?.boolValue == true {
            IdleInhibitService.shared.enable()
        }

        // Show DankBar & Dynamic Island
        DankBarController.shared.show()
        _ = DIslandController.shared
        DockController.shared.reposition()
        _ = WorkspaceService.shared
        _ = PluginService.shared
        _ = ToastController.shared
        _ = OSDController.shared
        _ = ClipboardService.shared
        _ = NowPlayingService.shared
        _ = WeatherService.shared

        print("DankMaterialShell for macOS started successfully.")
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if SettingsController.shared.isVisible {
            SettingsController.shared.hide()
            return .terminateCancel
        }
        return .terminateNow
    }

    public func applicationWillTerminate(_ notification: Notification) {
        ConfigStore.shared.flushSave()
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

    private var sigtermSource: (any DispatchSourceSignal)?
    private var sigintSource: (any DispatchSourceSignal)?

    private func setupSignalHandlers() {
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)

        let term = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        term.setEventHandler {
            ConfigStore.shared.flushSave()
            NSApp.terminate(nil)
        }
        term.resume()
        self.sigtermSource = term

        let intr = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        intr.setEventHandler {
            ConfigStore.shared.flushSave()
            NSApp.terminate(nil)
        }
        intr.resume()
        self.sigintSource = intr
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
