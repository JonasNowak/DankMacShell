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

    /// Set by SIGTERM/SIGINT handlers so termination is never blocked by an open Settings window.
    private var isForceTerminating = false

    /// Advisory single-instance lockfile FD, held open for the app lifetime.
    private var lockFD: Int32 = -1

    public func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("DMS Shell Daemon")

        // Enforce single instance via an advisory flock on a lockfile
        // (NSRunningApplication misses instances started outside LaunchServices).
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dmsDir = appSupport.appendingPathComponent("DMS", isDirectory: true)
        try? FileManager.default.createDirectory(at: dmsDir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dmsDir.path)
        let lockPath = dmsDir.appendingPathComponent("dms.lock").path
        let fd = open(lockPath, O_RDWR | O_CREAT, 0o600)
        if fd >= 0 {
            if flock(fd, LOCK_EX | LOCK_NB) != 0 {
                print("DMS is already running (lock held on \(lockPath)). Exiting duplicate instance.")
                close(fd)
                NSApp.terminate(nil)
                return
            }
            lockFD = fd
            ftruncate(fd, 0)
            let pidLine = "\(ProcessInfo.processInfo.processIdentifier)\n"
            _ = pidLine.withCString { write(fd, $0, strlen($0)) }
        } else {
            print("Warning: could not open lock file \(lockPath): \(String(cString: strerror(errno))) — single-instance check is advisory only.")
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

        // Show DankBar, Dynamic Island & Desktop Widgets
        DankBarController.shared.show()
        DesktopWidgetsController.shared.start()
        _ = DIslandController.shared
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

        // Automatic update check (skipped when the user disabled it in Settings -> About)
        if ConfigStore.shared.config.checkForUpdatesAutomatically {
            UpdateCheckService.shared.checkNow(force: false)
        }

        // First-run Welcome & Setup wizard (shown once, until onboardingCompleted is set)
        if !ConfigStore.shared.config.onboardingCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                OnboardingController.shared.show()
            }
        }

        print("DankMaterialShell for macOS started successfully.")
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Signals (SIGTERM/SIGINT from `dms stop` / `dms restart`) must always terminate,
        // even when the Settings window is open.
        if isForceTerminating {
            return .terminateNow
        }
        if SettingsController.shared.isVisible {
            SettingsController.shared.hide()
            return .terminateCancel
        }
        return .terminateNow
    }

    public func applicationWillTerminate(_ notification: Notification) {
        MediaKeyInterceptor.shared.stop()
        SystemOSDManager.resumeOSDUIHelperForTermination()
        WorkspaceService.shared.stopOmniWMSubscription()
        ConfigStore.shared.flushSave()
        NotepadService.shared.flushPendingSave()
        IPCSocketServer.shared.stop()
        HotkeyService.shared.unregisterAll()
        if lockFD >= 0 {
            flock(lockFD, LOCK_UN)
            close(lockFD)
            lockFD = -1
        }
    }

    private func setupAppIcon() {
        if NSApp.applicationIconImage == nil || NSApp.applicationIconImage.size == .zero {
            // Bundle.module fatalErrors when the resource bundle is missing — use the safe resolver.
            let resourceBundle = SafeResourceBundle.bundle(named: "DMS_DMS")
            let icon = Bundle.main.image(forResource: "AppIcon")
                ?? resourceBundle?.image(forResource: "AppIcon")
                ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:))
                ?? resourceBundle?.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:))
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

        // 5: Slanted Wallpaper Picker (customizable hotkey)
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
            self.isForceTerminating = true
            ConfigStore.shared.flushSave()
            NSApp.terminate(nil)
        }
        term.resume()
        self.sigtermSource = term

        let intr = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        intr.setEventHandler {
            self.isForceTerminating = true
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

        // Security allowlist: dms:// URLs may only trigger safe UI navigation/toggle actions.
        guard command.isAllowedFromURLScheme else {
            print("DMS: rejected dms:// URL — command not on the security allowlist: \(urlString)")
            return
        }

        _ = IPCCommandExecutor.execute(command)
    }
}
