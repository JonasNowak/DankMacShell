import AppKit
import SwiftUI
import Combine
import Carbon.HIToolbox
import Darwin
import DMSCore

private struct HotkeyConfig: Equatable {
    let launcher: Bool
    let launcherKey: String
    let launcherMods: String
    let dash: Bool
    let dashKey: String
    let dashMods: String
    let notepad: Bool
    let notepadKey: String
    let notepadMods: String
    let clipboard: Bool
    let clipboardKey: String
    let clipboardMods: String
    let picker: Bool
    let pickerKey: String
    let pickerMods: String
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("DMS Shell Daemon")

        // Enforce single instance (filter out self and dead/zombie processes)
        let myPID = ProcessInfo.processInfo.processIdentifier
        let activeInstances = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.jonasnowak.dms"
        ).filter { app in
            guard app.processIdentifier != myPID && !app.isTerminated else { return false }
            var bsdInfo = proc_bsdinfo()
            let size = proc_pidinfo(app.processIdentifier, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
            return size > 0 && bsdInfo.pbi_status != 5 /* SZOMB */
        }
        if !activeInstances.isEmpty {
            print("DMS is already running (PID: \(activeInstances.map { "\($0.processIdentifier)" }.joined(separator: ", "))). Exiting duplicate instance.")
            NSApp.terminate(nil)
            return
        }

        setupAppIcon()
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
        // v0.7 THEME: initial terminal theme export (palette didSet only fires on changes)
        TerminalThemeExporter.shared.exportIfEnabled(
            palette: ThemeStore.shared.palette,
            themeName: ThemeStore.shared.themeName,
            isDark: ThemeStore.shared.palette.isDark
        )
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
        if cfg.interceptMediaKeys {
            MediaKeyInterceptor.shared.start()
        }
        ConfigStore.shared.$config
            .map { $0.interceptMediaKeys }
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { shouldIntercept in
                if shouldIntercept {
                    MediaKeyInterceptor.shared.start()
                } else {
                    MediaKeyInterceptor.shared.stop()
                }
            }
            .store(in: &cancellables)

        ConfigStore.shared.$config
            .map { cfg -> HotkeyConfig in
                HotkeyConfig(
                    launcher: cfg.launcherHotkey,
                    launcherKey: cfg.launcherHotkeyKey,
                    launcherMods: cfg.launcherHotkeyModifiers,
                    dash: cfg.dashHotkey,
                    dashKey: cfg.dashHotkeyKey,
                    dashMods: cfg.dashHotkeyModifiers,
                    notepad: cfg.notepadHotkey,
                    notepadKey: cfg.notepadHotkeyKey,
                    notepadMods: cfg.notepadHotkeyModifiers,
                    clipboard: cfg.clipboardHotkey,
                    clipboardKey: cfg.clipboardHotkeyKey,
                    clipboardMods: cfg.clipboardHotkeyModifiers,
                    picker: cfg.wallpaperPickerHotkey,
                    pickerKey: cfg.wallpaperPickerHotkeyKey,
                    pickerMods: cfg.wallpaperPickerHotkeyModifiers
                )
            }
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupHotkeys()
            }
            .store(in: &cancellables)
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
        MediaKeyInterceptor.shared.stop()
        SystemOSDManager.resumeOSDUIHelperForTermination()
        ConfigStore.shared.flushSave()
        IPCSocketServer.shared.stop()
        HotkeyService.shared.unregisterAll()
    }

    private func setupAppIcon() {
        if NSApp.applicationIconImage == nil || NSApp.applicationIconImage.size == .zero {
            let icon = Bundle.main.image(forResource: "AppIcon")
                ?? Bundle.module.image(forResource: "AppIcon")
                ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:))
                ?? Bundle.module.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:))
            if let icon {
                NSApp.applicationIconImage = icon
            }
        }
    }

    private func setupHotkeys() {
        HotkeyService.shared.unregisterAll()
        let config = ConfigStore.shared.config

        // 1: Spotlight Launcher
        if config.launcherHotkey {
            let (keyCode, mods) = HotkeyHelper.parse(
                key: config.launcherHotkeyKey,
                modifiers: config.launcherHotkeyModifiers
            )
            HotkeyService.shared.register(id: 1, keyCode: keyCode, modifiers: mods) {
                LauncherController.shared.toggle()
            }
        }

        // 2: DankDash Overview
        if config.dashHotkey {
            let (keyCode, mods) = HotkeyHelper.parse(
                key: config.dashHotkeyKey,
                modifiers: config.dashHotkeyModifiers
            )
            HotkeyService.shared.register(id: 2, keyCode: keyCode, modifiers: mods) {
                DashController.shared.toggle()
            }
        }

        // 3: Notepad Scratchpad
        if config.notepadHotkey {
            let (keyCode, mods) = HotkeyHelper.parse(
                key: config.notepadHotkeyKey,
                modifiers: config.notepadHotkeyModifiers
            )
            HotkeyService.shared.register(id: 3, keyCode: keyCode, modifiers: mods) {
                NotepadController.shared.toggle()
            }
        }

        // 4: Clipboard History
        if config.clipboardHotkey {
            let (keyCode, mods) = HotkeyHelper.parse(
                key: config.clipboardHotkeyKey,
                modifiers: config.clipboardHotkeyModifiers
            )
            HotkeyService.shared.register(id: 4, keyCode: keyCode, modifiers: mods) {
                ClipboardController.shared.toggle()
            }
        }

        // 5: Slanted Wallpaper Picker (with Hyper Key / customizable hotkey)
        if config.wallpaperPickerHotkey {
            let (keyCode, mods) = HotkeyHelper.parse(
                key: config.wallpaperPickerHotkeyKey,
                modifiers: config.wallpaperPickerHotkeyModifiers
            )
            HotkeyService.shared.register(id: 5, keyCode: keyCode, modifiers: mods) {
                SlantedWallpaperPickerController.shared.triggerShortcut()
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
