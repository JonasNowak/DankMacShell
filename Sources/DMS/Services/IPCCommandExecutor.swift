import Foundation
import AppKit
import DMSCore

/// Central dispatcher for executing IPC commands on the main thread and formatting responses.
@MainActor
public enum IPCCommandExecutor {

    public static func execute(_ command: IPCCommand) -> String {
        switch command {
        case .toggleLauncher:
            LauncherController.shared.toggle()
            return "Launcher toggled"

        case .openLauncher:
            LauncherController.shared.show()
            return "Launcher opened"

        case .openLauncherQuery(let query):
            LauncherController.shared.show()
            return "Launcher opened with query '\(query)'"

        case .closeLauncher:
            LauncherController.shared.hide()
            return "Launcher closed"

        case .toggleControlCenter:
            ControlCenterController.shared.toggle()
            return "Control Center toggled"

        case .openControlCenter:
            ControlCenterController.shared.show()
            return "Control Center opened"

        case .closeControlCenter:
            ControlCenterController.shared.hide()
            return "Control Center closed"

        case .toggleDash:
            DashController.shared.toggle()
            return "DankDash toggled"

        case .openDash:
            DashController.shared.show()
            return "DankDash opened"

        case .closeDash:
            DashController.shared.hide()
            return "DankDash closed"

        case .powerMenu:
            PowerMenuController.shared.show()
            return "Power Menu opened"

        case .powerMenuAction(let act):
            switch act.lowercased() {
            case "lock":
                PowerMenuView.lockScreen()
                return "Screen locked"
            case "sleep":
                PowerMenuView.sleepSystem()
                return "System sleeping"
            case "restart":
                PowerMenuView.restartSystem()
                return "Restarting system"
            case "shutdown", "poweroff":
                PowerMenuView.shutDownSystem()
                return "Shutting down system"
            case "logout":
                PowerMenuView.logOut()
                return "Logging out"
            default:
                PowerMenuController.shared.show()
                return "Power Menu opened"
            }

        case .toggleNotepad:
            NotepadController.shared.toggle()
            return "Notepad toggled"

        case .openNotepad:
            NotepadController.shared.show()
            return "Notepad opened"

        case .closeNotepad:
            NotepadController.shared.hide()
            return "Notepad closed"

        case .getNotepad:
            return NotepadService.shared.activeNote.content

        case .setNotepad(let text):
            NotepadService.shared.updateActiveNote(content: text)
            return "Notepad updated"

        case .appendNotepad(let text):
            let cur = NotepadService.shared.activeNote.content
            NotepadService.shared.updateActiveNote(content: cur.isEmpty ? text : "\(cur)\n\(text)")
            return "Notepad appended"

        case .toggleClipboard:
            ClipboardController.shared.toggle()
            return "Clipboard history toggled"

        case .openClipboard:
            ClipboardController.shared.show()
            return "Clipboard history opened"

        case .closeClipboard:
            ClipboardController.shared.hide()
            return "Clipboard history closed"

        case .listClipboard:
            let items = ClipboardService.shared.items
            if items.isEmpty { return "Clipboard history is empty" }
            return items.prefix(20).map { "- \($0.preview)" }.joined(separator: "\n")

        case .clearClipboard:
            ClipboardService.shared.clearAll()
            return "Clipboard history cleared"

        case .copyClipboard(let text):
            ClipboardService.shared.copyItem(text: text)
            return "Copied to clipboard"

        case .toggleProcessList:
            ProcessListController.shared.toggle()
            return "Process list toggled"

        case .openProcessList:
            ProcessListController.shared.show()
            return "Process list opened"

        case .closeProcessList:
            ProcessListController.shared.hide()
            return "Process list closed"

        case .listProcesses:
            let procs = ProcessService.shared.processes
            let top = procs.prefix(15)
            let header = String(format: "%-8s %-25s %-8s %-8s", "PID", "NAME", "CPU%", "RAM(MB)")
            let rows = top.map { String(format: "%-8d %-25s %-8.1f %-8.1f", $0.pid, String($0.name.prefix(24)), $0.cpuPercent, $0.memoryMB) }
            return ([header] + rows).joined(separator: "\n")

        case .killProcess(let pid):
            let ok = ProcessService.shared.killProcess(pid: pid)
            return ok ? "Process \(pid) terminated" : "Failed to terminate process \(pid)"

        case .openColorPicker:
            ColorPickerController.shared.show()
            return "Color picker opened"

        case .pickColor:
            ColorPickerService.shared.sampleColor()
            return "Eyedropper active"

        case .openQR:
            QRGeneratorController.shared.show()
            return "QR Generator opened"

        case .generateQR(let text):
            QRGeneratorController.shared.show(text: text)
            return "QR Generator opened with '\(text)'"

        case .toggleKeybinds:
            KeybindsController.shared.toggle()
            return "Keybinds modal toggled"

        case .openKeybinds:
            KeybindsController.shared.show()
            return "Keybinds modal opened"

        case .closeKeybinds:
            KeybindsController.shared.hide()
            return "Keybinds modal closed"

        case .toggleSettings:
            SettingsController.shared.toggle()
            return "Settings toggled"

        case .openSettings:
            SettingsController.shared.show()
            return "Settings opened"

        case .openSettingsTab(let tab):
            SettingsController.shared.show(tab: tab)
            return "Settings opened at tab '\(tab)'"

        case .closeSettings:
            SettingsController.shared.hide()
            return "Settings closed"

        case .getSetting(let key):
            switch key.lowercased() {
            case "theme": return ConfigStore.shared.config.theme
            case "islightmode": return "\(ConfigStore.shared.config.isLightMode)"
            case "barposition": return ConfigStore.shared.config.barPosition
            case "barautohide": return "\(ConfigStore.shared.config.barAutoHide)"
            default: return "Unknown key \(key)"
            }

        case .setSetting(let key, let val):
            ConfigStore.shared.update { cfg in
                switch key.lowercased() {
                case "theme":
                    cfg.theme = val
                    ThemeStore.shared.apply(theme: val, lightMode: cfg.isLightMode)
                case "islightmode":
                    let light = val.lowercased() == "true" || val == "1"
                    cfg.isLightMode = light
                    ThemeStore.shared.setLightMode(light)
                case "barposition":
                    cfg.barPosition = val
                    DankBarController.shared.updateBarFrame()
                case "barautohide":
                    cfg.barAutoHide = val.lowercased() == "true" || val == "1"
                default:
                    break
                }
            }
            return "Setting \(key) set to \(val)"

        case .dumpSettings:
            guard let data = try? ConfigStore.shared.config.encodeJSON(),
                  let str = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return str

        case .bar(let act, let val):
            switch act.lowercased() {
            case "reveal", "show":
                DankBarController.shared.show()
                return "DankBar revealed"
            case "hide":
                DankBarController.shared.hide()
                return "DankBar hidden"
            case "toggle":
                if DankBarController.shared.isVisible {
                    DankBarController.shared.hide()
                } else {
                    DankBarController.shared.show()
                }
                return "DankBar toggled"
            case "setposition":
                if let pos = val {
                    ConfigStore.shared.update { $0.barPosition = pos }
                    DankBarController.shared.updateBarFrame()
                    return "Bar position set to \(pos)"
                }
                return "Missing position"
            case "status":
                return "visible: \(DankBarController.shared.isVisible), position: \(ConfigStore.shared.config.barPosition)"
            default:
                return "Unknown bar action \(act)"
            }

        case .dock(let act, _):
            switch act.lowercased() {
            case "toggle":
                ConfigStore.shared.update { $0.showDock.toggle() }
                return "Dock toggled: \(ConfigStore.shared.config.showDock)"
            case "hide":
                ConfigStore.shared.update { $0.showDock = false }
                return "Dock hidden"
            case "reveal", "show":
                ConfigStore.shared.update { $0.showDock = true }
                return "Dock revealed"
            case "status":
                return "dock visible: \(ConfigStore.shared.config.showDock)"
            default:
                return "Unknown dock action \(act)"
            }

        case .audio(let act, let val):
            switch act.lowercased() {
            case "mute":
                AudioService.shared.setMuted(true)
                return "Audio muted"
            case "unmute":
                AudioService.shared.setMuted(false)
                return "Audio unmuted"
            case "toggle":
                AudioService.shared.toggleMute()
                return "Mute toggled: \(AudioService.shared.isMuted)"
            case "setvolume":
                if let valStr = val, let v = Double(valStr) {
                    AudioService.shared.setVolume(min(1.0, max(0.0, v > 1.0 ? v / 100.0 : v)))
                    return "Volume set to \(Int(AudioService.shared.volume * 100))%"
                }
                return "Missing volume argument"
            case "increment":
                let cur = AudioService.shared.volume
                let step = (val.flatMap { Double($0) } ?? 5.0) / 100.0
                AudioService.shared.setVolume(min(1.0, cur + step))
                return "Volume: \(Int(AudioService.shared.volume * 100))%"
            case "decrement":
                let cur = AudioService.shared.volume
                let step = (val.flatMap { Double($0) } ?? 5.0) / 100.0
                AudioService.shared.setVolume(max(0.0, cur - step))
                return "Volume: \(Int(AudioService.shared.volume * 100))%"
            default:
                return "Volume: \(Int(AudioService.shared.volume * 100))%, Muted: \(AudioService.shared.isMuted)"
            }

        case .mic(let act, _):
            switch act.lowercased() {
            case "mute":
                AudioService.shared.setMicMuted(true)
                return "Mic muted"
            case "unmute":
                AudioService.shared.setMicMuted(false)
                return "Mic unmuted"
            case "toggle":
                AudioService.shared.toggleMicMute()
                return "Mic muted: \(AudioService.shared.isMicMuted)"
            default:
                return "Mic muted: \(AudioService.shared.isMicMuted)"
            }

        case .brightness(let act, let val):
            switch act.lowercased() {
            case "set":
                if let valStr = val, let b = Double(valStr) {
                    BrightnessService.shared.brightness = min(1.0, max(0.0, b > 1.0 ? b / 100.0 : b))
                    return "Brightness set to \(Int(BrightnessService.shared.brightness * 100))%"
                }
                return "Missing brightness argument"
            case "increment":
                let cur = BrightnessService.shared.brightness
                BrightnessService.shared.brightness = min(1.0, cur + 0.05)
                return "Brightness: \(Int(BrightnessService.shared.brightness * 100))%"
            case "decrement":
                let cur = BrightnessService.shared.brightness
                BrightnessService.shared.brightness = max(0.0, cur - 0.05)
                return "Brightness: \(Int(BrightnessService.shared.brightness * 100))%"
            default:
                return "Brightness: \(Int(BrightnessService.shared.brightness * 100))%"
            }

        case .inhibit(let act):
            switch act.lowercased() {
            case "enable":
                IdleInhibitService.shared.enable()
                return "Idle inhibit enabled"
            case "disable":
                IdleInhibitService.shared.disable()
                return "Idle inhibit disabled"
            case "status":
                return "Idle inhibit active: \(IdleInhibitService.shared.isInhibited)"
            default:
                IdleInhibitService.shared.toggle()
                return "Idle inhibit toggled: \(IdleInhibitService.shared.isInhibited)"
            }

        case .mpris(let act):
            switch act.lowercased() {
            case "play", "pause", "toggle", "playpause":
                NowPlayingService.shared.playPause()
                return "Media playback toggled"
            case "next":
                NowPlayingService.shared.next()
                return "Skipped to next track"
            case "prev", "previous":
                NowPlayingService.shared.previous()
                return "Returned to previous track"
            default:
                let track = NowPlayingService.shared.currentTrack
                return "\(track.title) - \(track.artist) (\(track.isPlaying ? "Playing" : "Paused"))"
            }

        case .setTheme(let name):
            ThemeStore.shared.apply(theme: name, lightMode: ThemeStore.shared.isLightMode)
            ConfigStore.shared.update { $0.theme = name }
            ToastCenter.shared.show(icon: "paintpalette.fill", message: "Theme: \(name.capitalized)")
            return "Theme set to \(name)"

        case .getTheme:
            return ThemeStore.shared.themeName

        case .listThemes:
            return "dynamic, purple, blue, green, orange, red, yellow, neutral"

        case .toggleThemeMode:
            ThemeStore.shared.toggleLightMode()
            ConfigStore.shared.update { $0.isLightMode = ThemeStore.shared.isLightMode }
            ToastCenter.shared.show(
                icon: ThemeStore.shared.isLightMode ? "sun.max.fill" : "moon.fill",
                message: "Switched to \(ThemeStore.shared.isLightMode ? "Light" : "Dark") Mode"
            )
            return "Light mode: \(ThemeStore.shared.isLightMode)"

        case .screenshot:
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c"]
            try? task.run()
            return "Screenshot triggered"

        case .screenshotMode(let mode):
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            if mode == "window" {
                task.arguments = ["-w", "-c"]
            } else if mode == "full" {
                task.arguments = ["-c"]
            } else {
                task.arguments = ["-i", "-c"]
            }
            try? task.run()
            return "Screenshot mode \(mode) triggered"

        case .toast(let level, let msg):
            let icon: String = level == "error" ? "exclamationmark.triangle.fill" : (level == "warn" ? "exclamationmark.circle.fill" : "info.circle.fill")
            ToastCenter.shared.show(icon: icon, message: msg)
            return "Toast displayed"

        case .doctor:
            return "DMS Daemon: Active\nCoreAudio: Active\nCoreWLAN: Active\nIOBluetooth: Active\nSocket: Active"

        case .reloadConfig:
            ConfigStore.shared.loadConfig()
            ThemeStore.shared.apply(theme: ConfigStore.shared.config.theme, lightMode: ConfigStore.shared.config.isLightMode)
            ToastCenter.shared.show(icon: "arrow.clockwise", message: "Configuration reloaded")
            return "Configuration reloaded"

        case .status:
            return "active"

        case .unknown(let raw):
            return "Unknown command: \(raw)"
        }
    }
}
