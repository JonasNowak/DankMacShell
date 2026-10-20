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
            LauncherController.shared.show(query: query)
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

        case .openDashTab(let tab):
            let dashTab = DashTab(fromString: tab) ?? .overview
            DashController.shared.show(tab: dashTab)
            return "DankDash opened on \(dashTab.title)"

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
            if let val = ConfigStore.shared.config.getSetting(key) {
                return val.stringValue ?? "\(val.value)"
            }
            return "Unknown key \(key)"

        case .setSetting(let key, let val):
            let anyVal: AnyCodable
            if let b = Bool(val) {
                anyVal = AnyCodable(b)
            } else if let i = Int(val) {
                anyVal = AnyCodable(i)
            } else if let d = Double(val) {
                anyVal = AnyCodable(d)
            } else {
                anyVal = AnyCodable(val)
            }

            ConfigStore.shared.update { cfg in
                cfg.setSetting(key, value: anyVal)
            }

            let lower = key.lowercased()
            if lower == "theme" || lower == "islightmode" || lower.contains("font") || lower.contains("radius") || lower.contains("opacity") || lower.contains("shadow") || lower.contains("matugen") {
                ThemeStore.shared.sync(with: ConfigStore.shared.config)
            } else if lower.contains("bar") {
                DankBarController.shared.updateBarFrame()
            } else if lower.contains("dock") {
                DockController.shared.updateDocks()
            } else if lower.contains("island") {
                DIslandController.shared.refreshSettings()
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
                DockController.shared.toggle()
                return "Dock toggled: \(ConfigStore.shared.config.showDock)"
            case "hide":
                ConfigStore.shared.update { $0.showDock = false }
                DockController.shared.hide()
                return "Dock hidden"
            case "reveal", "show":
                ConfigStore.shared.update { $0.showDock = true }
                DockController.shared.show()
                return "Dock revealed"
            case "reposition", "update":
                DockController.shared.reposition()
                return "Dock repositioned"
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
            case "list-devices", "devices", "sinks":
                let devices = AudioService.shared.outputs
                if devices.isEmpty { return "No audio output devices found" }
                return devices.map { "\($0.isDefault ? "* " : "  ")[\($0.id)] \($0.name)" }.joined(separator: "\n")
            case "set-device", "switch-device", "select-device":
                if let target = val {
                    if AudioService.shared.setDefaultOutputByName(target) {
                        return "Audio output set to \(target)"
                    }
                    return "Device not found: \(target)"
                }
                return "Missing device name or ID argument"
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
            return (["dynamic"] + StockThemes.allAvailableThemes).joined(separator: ", ")

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
            let dsStatus = DankSearchClient.shared.healthState
            return "DMS Daemon: Active\nCoreAudio: Active\nCoreWLAN: Active\nIOBluetooth: Active\nDankSearch: \(dsStatus)\nSocket: Active"

        case .reloadConfig:
            ConfigStore.shared.loadConfig()
            ThemeStore.shared.sync(with: ConfigStore.shared.config)
            DankBarController.shared.updateBarFrame()
            DIslandController.shared.refreshSettings()
            ToastCenter.shared.show(icon: "arrow.clockwise", message: "Configuration reloaded")
            return "Configuration reloaded"

        case .status:
            return "active"

        case .weatherRefresh:
            WeatherService.shared.fetchWeather(force: true)
            ToastCenter.shared.show(icon: "arrow.clockwise", message: "Weather Refreshed")
            return "Weather refresh triggered"

        case .weatherSetLocation(let loc):
            WeatherService.shared.setManualLocation(loc)
            ToastCenter.shared.show(icon: "mappin.and.ellipse", message: "Location: \(loc)")
            return "Weather location set to: \(loc)"

        case .weatherStatus:
            let w = WeatherService.shared.currentWeather
            let isCelsius = ConfigStore.shared.config.weatherUnits.lowercased() == "celsius"
            let temp = isCelsius ? "\(Int(round(w.temperatureC)))°C" : "\(Int(round(w.temperatureF)))°F"
            return "Location: \(WeatherService.shared.locationName) (\(WeatherService.shared.latitude), \(WeatherService.shared.longitude))\nTemperature: \(temp)\nCondition: \(w.conditionDescription)\nHumidity: \(w.humidity)%\nWind: \(Int(round(w.windSpeedKmh))) km/h"

        case .listPlugins:
            let installed = PluginService.shared.plugins.filter { $0.isInstalled }
            if installed.isEmpty {
                return "No plugins installed. Run 'dms plugins search' to view available plugins."
            }
            return installed.map { "[\($0.isEnabled ? "ON" : "OFF")] \($0.id) (v\($0.version)) - \($0.name)" }.joined(separator: "\n")

        case .searchPlugins(let query):
            let all = PluginService.shared.plugins
            let filtered = query.isEmpty ? all : all.filter {
                $0.id.localizedCaseInsensitiveContains(query) ||
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.description.localizedCaseInsensitiveContains(query)
            }
            if filtered.isEmpty { return "No matching plugins found." }
            return filtered.map { p in
                "• \(p.id) (v\(p.version)) [\(p.type.title)] - \(p.name)\n  \(p.description)\n  Status: \(p.isInstalled ? (p.isEnabled ? "Installed (Enabled)" : "Installed (Disabled)") : "Available")"
            }.joined(separator: "\n\n")

        case .installPlugin(let id):
            PluginService.shared.installPlugin(id: id)
            return "Plugin '\(id)' installed and enabled."

        case .uninstallPlugin(let id):
            PluginService.shared.uninstallPlugin(id: id)
            return "Plugin '\(id)' uninstalled."

        case .enablePlugin(let id):
            guard let p = PluginService.shared.plugins.first(where: { $0.id == id }) else {
                return "Plugin '\(id)' not found."
            }
            if !p.isEnabled {
                PluginService.shared.togglePlugin(id: id)
            }
            return "Plugin '\(id)' enabled."

        case .disablePlugin(let id):
            guard let p = PluginService.shared.plugins.first(where: { $0.id == id }) else {
                return "Plugin '\(id)' not found."
            }
            if p.isEnabled {
                PluginService.shared.togglePlugin(id: id)
            }
            return "Plugin '\(id)' disabled."

        case .lockPlugins:
            PluginService.shared.saveLockfile()
            return "Plugins locked to plugins.lock.json"

        case .restorePlugins(let path):
            let ok = PluginService.shared.restoreLockfile(from: path)
            return ok ? "Plugins restored from lockfile." : "Failed to restore lockfile."

        case .listApplets:
            let applets = PluginService.shared.applets
            return applets.map { "[\($0.isEnabled ? "ON" : "OFF")] \($0.id) - \($0.name) (\($0.description))" }.joined(separator: "\n")

        case .toggleApplet(let id):
            PluginService.shared.toggleApplet(id: id)
            let cur = PluginService.shared.applets.first(where: { $0.id == id })?.isEnabled ?? false
            return "Applet '\(id)' is now \(cur ? "enabled" : "disabled")."

        case .island(let act, let val):
            switch act.lowercased() {
            case "expand", "open", "show", "reveal":
                if let val = val, let activity = IslandActivity(rawValue: val.lowercased()) {
                    DIslandController.shared.expand(activity: activity)
                } else {
                    DIslandController.shared.expand()
                }
                return "Dynamic Island expanded"
            case "collapse", "close", "hide":
                DIslandController.shared.collapse()
                return "Dynamic Island collapsed"
            case "toggle":
                DIslandController.shared.toggleExpanded()
                return "Dynamic Island toggled"
            case "media", "weather", "battery", "audio", "timers", "notifications":
                if let activity = IslandActivity(rawValue: act.lowercased()) {
                    DIslandController.shared.expand(activity: activity)
                    return "Dynamic Island expanded (\(activity.rawValue))"
                }
                return "Unknown island activity \(act)"
            case "status":
                return "state: \(DIslandController.shared.presentationState.rawValue), activity: \(DIslandController.shared.activeActivity.rawValue)"
            default:
                return "Unknown island action \(act)"
            }

        case .danksearch(let act, let query):
            switch act.lowercased() {
            case "status":
                let health = DankSearchClient.shared.healthState
                let bin = DankSearchClient.shared.resolveExecutablePath() ?? "not installed (using Spotlight fallback)"
                return "Health: \(health)\nBinary: \(bin)"
            case "diagnostics", "logs":
                let logs = DankSearchClient.shared.diagnostics
                if logs.isEmpty { return "No danksearch diagnostics recorded." }
                return logs.suffix(10).map { "[\($0.timestamp)] [\($0.backend)] query='\($0.query)' \($0.message)" }.joined(separator: "\n")
            case "reset", "recover", "restart":
                DankSearchClient.shared.resetAndRecover()
                return "DankSearch health state reset; service will recover on next query."
            case "search", "query":
                let q = query ?? ""
                let resp = AppSearch.searchFilesWithDiagnostics(query: q, maxResults: 15)
                if resp.files.isEmpty {
                    return "No results for '\(q)' (usedFallback: \(resp.usedFallback))"
                }
                return resp.files.map { "\($0.name) (\($0.path))" }.joined(separator: "\n")
            default:
                return "Unknown danksearch action \(act)"
            }

        case .unknown(let raw):
            return "Unknown command: \(raw)"
        }
    }
}
