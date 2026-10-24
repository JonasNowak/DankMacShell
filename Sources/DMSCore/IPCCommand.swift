import Foundation

/// Structured command representation for all DMS IPC actions.
public enum IPCCommand: Sendable, Equatable {
    // Launcher / Spotlight
    case toggleLauncher
    case openLauncher
    case openLauncherQuery(query: String)
    case closeLauncher

    // Control Center
    case toggleControlCenter
    case openControlCenter
    case closeControlCenter

    // Dash / Overview
    case toggleDash
    case openDash
    case openDashTab(tab: String)
    case closeDash

    // Power Menu & Session
    case powerMenu
    case powerMenuAction(String)

    // Notepad
    case toggleNotepad
    case openNotepad
    case closeNotepad
    case getNotepad
    case setNotepad(text: String)
    case appendNotepad(text: String)

    // Clipboard History
    case toggleClipboard
    case openClipboard
    case closeClipboard
    case listClipboard
    case clearClipboard
    case copyClipboard(text: String)

    // Process List / Task Manager
    case toggleProcessList
    case openProcessList
    case closeProcessList
    case listProcesses
    case killProcess(pid: Int32)

    // Application Visibility & Window Control (Unhide/Hide/Activate)
    case unhideApp(bundleID: String, inBackground: Bool)
    case unhideAllApps(inBackground: Bool)
    case hideApp(bundleID: String)
    case activateApp(bundleID: String)

    // Color Picker
    case openColorPicker
    case pickColor

    // QR Code Generator
    case openQR
    case generateQR(text: String)

    // Keybinds Cheatsheet
    case toggleKeybinds
    case openKeybinds
    case closeKeybinds

    // Settings
    case toggleSettings
    case openSettings
    case openSettingsTab(String)
    case closeSettings
    case getSetting(key: String)
    case setSetting(key: String, value: String)
    case dumpSettings

    // DankBar & Dock
    case bar(action: String, value: String? = nil)
    case dock(action: String, value: String? = nil)

    // Hardware & Media Controls
    case audio(action: String, value: String? = nil)
    case mic(action: String, value: String? = nil)
    case brightness(action: String, value: String? = nil)
    case inhibit(action: String)
    case mpris(action: String)

    // Theming
    case setTheme(name: String)
    case getTheme
    case listThemes
    case toggleThemeMode

    // System / Diagnostics
    case screenshot
    case screenshotMode(String)
    case toast(level: String, message: String)
    case doctor
    case reloadConfig
    case status

    // Plugins & Applets
    case listPlugins
    case searchPlugins(query: String)
    case installPlugin(id: String)
    case uninstallPlugin(id: String)
    case enablePlugin(id: String)
    case disablePlugin(id: String)
    case lockPlugins
    case restorePlugins(path: String?)
    case listApplets
    case toggleApplet(id: String)

    // Weather
    case weatherRefresh
    case weatherSetLocation(location: String)
    case weatherStatus

    // Dynamic Island (Spec 24)
    case island(action: String, value: String? = nil)

    // Danksearch / File Search Diagnostics & Control (Spec 18 / 35)
    case danksearch(action: String, query: String? = nil)

    case unknown(String)

    // MARK: - URL Parser (dms:// scheme)
    public static func parse(url: URL) -> IPCCommand? {
        guard url.scheme?.lowercased() == "dms" else { return nil }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let command = host.isEmpty ? path : host
        let subPath = host.isEmpty ? "" : path

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func param(_ name: String) -> String? {
            queryItems.first(where: { $0.name.lowercased() == name.lowercased() })?.value
        }

        switch command {
        case "togglelauncher", "launcher":
            if subPath == "open" || param("action") == "open" {
                if let q = param("q") ?? param("query"), !q.isEmpty {
                    return .openLauncherQuery(query: q)
                }
                return .openLauncher
            } else if subPath == "close" || param("action") == "close" {
                return .closeLauncher
            }
            return .toggleLauncher

        case "openlauncher":
            if let q = param("q") ?? param("query"), !q.isEmpty {
                return .openLauncherQuery(query: q)
            }
            return .openLauncher

        case "closelauncher":
            return .closeLauncher

        case "togglecontrolcenter", "controlcenter", "control-center":
            if subPath == "open" || param("action") == "open" { return .openControlCenter }
            if subPath == "close" || param("action") == "close" { return .closeControlCenter }
            return .toggleControlCenter

        case "opencontrolcenter":
            return .openControlCenter
        case "closecontrolcenter":
            return .closeControlCenter

        case "toggledash", "dash", "dankdash":
            if let tab = param("tab"), !tab.isEmpty {
                return .openDashTab(tab: tab)
            }
            if subPath == "open" || param("action") == "open" { return .openDash }
            if subPath == "close" || param("action") == "close" { return .closeDash }
            return .toggleDash

        case "powermenu":
            if let act = param("action") ?? (subPath.isEmpty ? nil : subPath), !act.isEmpty {
                return .powerMenuAction(act)
            }
            return .powerMenu

        case "notepad":
            if subPath == "get" || param("action") == "get" { return .getNotepad }
            if (subPath == "set" || param("action") == "set"), let text = param("text") { return .setNotepad(text: text) }
            if (subPath == "append" || param("action") == "append"), let text = param("text") { return .appendNotepad(text: text) }
            if subPath == "open" || param("action") == "open" { return .openNotepad }
            if subPath == "close" || param("action") == "close" { return .closeNotepad }
            return .toggleNotepad

        case "clipboard":
            if subPath == "list" || param("action") == "list" { return .listClipboard }
            if subPath == "clear" || param("action") == "clear" { return .clearClipboard }
            if (subPath == "copy" || param("action") == "copy"), let text = param("text") { return .copyClipboard(text: text) }
            if subPath == "open" || param("action") == "open" { return .openClipboard }
            return .toggleClipboard

        case "processlist", "processes":
            if subPath == "list" || param("action") == "list" { return .listProcesses }
            if (subPath == "kill" || param("action") == "kill"), let pidStr = param("pid"), let pid = Int32(pidStr) {
                return .killProcess(pid: pid)
            }
            if subPath == "open" || param("action") == "open" { return .openProcessList }
            return .toggleProcessList

        case "unhide":
            let id = param("id") ?? param("bundleid") ?? subPath
            let inBackground = param("background")?.lowercased() == "true" || param("inbackground")?.lowercased() == "true"
            if id.isEmpty || id == "all" {
                return .unhideAllApps(inBackground: inBackground)
            }
            return .unhideApp(bundleID: id, inBackground: inBackground)

        case "unhideall", "unhide-all":
            let inBackground = param("background")?.lowercased() == "true" || param("inbackground")?.lowercased() == "true"
            return .unhideAllApps(inBackground: inBackground)

        case "hide":
            let id = param("id") ?? param("bundleid") ?? subPath
            if !id.isEmpty { return .hideApp(bundleID: id) }
            return .unknown("hide requires bundle id")

        case "activate":
            let id = param("id") ?? param("bundleid") ?? subPath
            if !id.isEmpty { return .activateApp(bundleID: id) }
            return .unknown("activate requires bundle id")

        case "colorpicker":
            if subPath == "pick" || param("action") == "pick" { return .pickColor }
            return .openColorPicker

        case "qr":
            if let text = param("text") ?? param("q"), !text.isEmpty { return .generateQR(text: text) }
            return .openQR

        case "keybinds":
            if subPath == "open" || param("action") == "open" { return .openKeybinds }
            if subPath == "close" || param("action") == "close" { return .closeKeybinds }
            return .toggleKeybinds

        case "settings":
            if subPath == "dump" || param("action") == "dump" { return .dumpSettings }
            if let key = param("key"), let val = param("value") { return .setSetting(key: key, value: val) }
            if let key = param("key") { return .getSetting(key: key) }
            if let tab = param("tab") { return .openSettingsTab(tab) }
            if subPath == "open" || param("action") == "open" { return .openSettings }
            return .toggleSettings

        case "bar":
            let act = subPath.isEmpty ? (param("action") ?? "toggle") : subPath
            return .bar(action: act, value: param("value") ?? param("position"))

        case "dock":
            let act = subPath.isEmpty ? (param("action") ?? "toggle") : subPath
            return .dock(action: act, value: param("value"))

        case "audio":
            let act = subPath.isEmpty ? (param("action") ?? "status") : subPath
            return .audio(action: act, value: param("volume") ?? param("value"))

        case "mic":
            let act = subPath.isEmpty ? (param("action") ?? "status") : subPath
            return .mic(action: act, value: param("volume") ?? param("value"))

        case "brightness":
            let act = subPath.isEmpty ? (param("action") ?? "get") : subPath
            return .brightness(action: act, value: param("value") ?? param("level"))

        case "inhibit":
            let act = subPath.isEmpty ? (param("action") ?? "toggle") : subPath
            return .inhibit(action: act)

        case "mpris":
            let act = subPath.isEmpty ? (param("action") ?? "status") : subPath
            return .mpris(action: act)

        case "settheme":
            if let name = param("name") { return .setTheme(name: name) }
            return .unknown("settheme missing name")

        case "theme":
            if subPath == "toggle" || param("action") == "toggle" { return .toggleThemeMode }
            if subPath == "list" || param("action") == "list" { return .listThemes }
            if subPath == "get" || param("action") == "get" { return .getTheme }
            if let name = param("name") ?? param("value") { return .setTheme(name: name) }
            return .getTheme

        case "togglethememode":
            return .toggleThemeMode

        case "screenshot":
            if let mode = param("mode") ?? (subPath.isEmpty ? nil : subPath), !mode.isEmpty {
                return .screenshotMode(mode)
            }
            return .screenshot

        case "toast":
            return .toast(level: param("level") ?? "info", message: param("msg") ?? param("message") ?? "")

        case "doctor":
            return .doctor

        case "reloadconfig":
            return .reloadConfig

        case "plugins", "plugin":
            let act = param("action") ?? subPath
            if act == "search" { return .searchPlugins(query: param("q") ?? param("query") ?? "") }
            if act == "install", let id = param("id") { return .installPlugin(id: id) }
            if act == "uninstall", let id = param("id") { return .uninstallPlugin(id: id) }
            if act == "enable", let id = param("id") { return .enablePlugin(id: id) }
            if act == "disable", let id = param("id") { return .disablePlugin(id: id) }
            if act == "lock" { return .lockPlugins }
            if act == "restore" { return .restorePlugins(path: param("path")) }
            return .listPlugins

        case "applets", "applet":
            let act = param("action") ?? subPath
            if act == "toggle", let id = param("id") { return .toggleApplet(id: id) }
            return .listApplets

        case "status":
            return .status

        case "weather":
            let act = param("action") ?? subPath
            if act == "refresh" || act == "reload" { return .weatherRefresh }
            if act == "set" || act == "location", let loc = param("location") ?? param("loc") ?? param("q") {
                return .weatherSetLocation(location: loc)
            }
            if let loc = param("location") ?? param("q") {
                return .weatherSetLocation(location: loc)
            }
            return .weatherStatus

        case "island", "disland":
            let act = subPath.isEmpty ? (param("action") ?? "toggle") : subPath
            return .island(action: act, value: param("value") ?? param("activity") ?? param("edge"))

        case "danksearch", "dsearch":
            let act = subPath.isEmpty ? (param("action") ?? "status") : subPath
            return .danksearch(action: act, query: param("q") ?? param("query"))

        default:
            return .unknown(url.absoluteString)
        }
    }

    // MARK: - CLI IPC Parser (e.g. "ipc call <target> <action> [args...]")
    public static func parseCLI(args: [String]) -> IPCCommand {
        guard !args.isEmpty else { return .status }

        var tokens = args
        // Strip leading "ipc" and "call" if user ran `dms ipc call ...`
        if tokens.first?.lowercased() == "ipc" {
            tokens.removeFirst()
        }
        if tokens.first?.lowercased() == "call" {
            tokens.removeFirst()
        }

        guard let target = tokens.first?.lowercased() else { return .status }
        let rawAction = tokens.count > 1 ? tokens[1] : ""
        let action = rawAction.lowercased()
        let extra = tokens.count > 2 ? Array(tokens.dropFirst(2)) : []

        switch target {
        case "spotlight", "launcher":
            switch action {
            case "open":
                if let q = extra.first, !q.isEmpty {
                    return .openLauncherQuery(query: extra.joined(separator: " "))
                }
                return .openLauncher
            case "close":
                return .closeLauncher
            case "openquery":
                return .openLauncherQuery(query: extra.joined(separator: " "))
            default:
                return .toggleLauncher
            }

        case "control-center", "controlcenter":
            switch action {
            case "open": return .openControlCenter
            case "close": return .closeControlCenter
            default: return .toggleControlCenter
            }

        case "dash", "dankdash":
            switch action {
            case "open":
                if let tabIdx = extra.firstIndex(of: "--tab"), tabIdx + 1 < extra.count {
                    return .openDashTab(tab: extra[tabIdx + 1])
                } else if let first = extra.first, !first.starts(with: "-") {
                    return .openDashTab(tab: first)
                }
                return .openDash
            case "opentab":
                if let first = extra.first { return .openDashTab(tab: first) }
                return .openDash
            case "close": return .closeDash
            default: return .toggleDash
            }

        case "powermenu":
            if !action.isEmpty && action != "open" {
                return .powerMenuAction(action)
            }
            return .powerMenu

        case "notepad":
            switch action {
            case "open": return .openNotepad
            case "close": return .closeNotepad
            case "get": return .getNotepad
            case "set": return .setNotepad(text: extra.joined(separator: " "))
            case "append": return .appendNotepad(text: extra.joined(separator: " "))
            default: return .toggleNotepad
            }

        case "clipboard":
            switch action {
            case "list": return .listClipboard
            case "clear": return .clearClipboard
            case "copy": return .copyClipboard(text: extra.joined(separator: " "))
            case "open": return .openClipboard
            default: return .toggleClipboard
            }

        case "processlist", "processes":
            switch action {
            case "list": return .listProcesses
            case "kill":
                if let pidStr = extra.first, let pid = Int32(pidStr) {
                    return .killProcess(pid: pid)
                }
                return .unknown("kill missing pid")
            case "open": return .openProcessList
            default: return .toggleProcessList
            }

        case "unhide":
            let isBg = tokens.contains("--background") || tokens.contains("-b")
            let targetID = rawAction.starts(with: "-") ? "" : rawAction
            if targetID.isEmpty || targetID.lowercased() == "all" {
                return .unhideAllApps(inBackground: isBg)
            }
            return .unhideApp(bundleID: targetID, inBackground: isBg)

        case "unhide-all", "unhideall":
            let isBg = tokens.contains("--background") || tokens.contains("-b")
            return .unhideAllApps(inBackground: isBg)

        case "hide":
            guard !rawAction.isEmpty && !rawAction.starts(with: "-") else {
                return .unknown("hide requires bundle identifier")
            }
            return .hideApp(bundleID: rawAction)

        case "activate":
            guard !rawAction.isEmpty && !rawAction.starts(with: "-") else {
                return .unknown("activate requires bundle identifier")
            }
            return .activateApp(bundleID: rawAction)

        case "colorpicker":
            if action == "pick" { return .pickColor }
            return .openColorPicker

        case "qr":
            if !action.isEmpty { return .generateQR(text: ([action] + extra).joined(separator: " ")) }
            return .openQR

        case "keybinds":
            switch action {
            case "open": return .openKeybinds
            case "close": return .closeKeybinds
            default: return .toggleKeybinds
            }

        case "settings":
            switch action {
            case "dump": return .dumpSettings
            case "get": return .getSetting(key: extra.first ?? "")
            case "set":
                if extra.count >= 2 { return .setSetting(key: extra[0], value: extra[1]) }
                return .unknown("settings set requires key and value")
            case "open":
                if let tab = extra.first { return .openSettingsTab(tab) }
                return .openSettings
            case "close": return .closeSettings
            default: return .toggleSettings
            }

        case "bar":
            return .bar(action: action.isEmpty ? "toggle" : action, value: extra.first)

        case "dock":
            return .dock(action: action.isEmpty ? "toggle" : action, value: extra.first)

        case "audio":
            return .audio(action: action.isEmpty ? "status" : action, value: extra.first)

        case "mic":
            return .mic(action: action.isEmpty ? "status" : action, value: extra.first)

        case "brightness":
            return .brightness(action: action.isEmpty ? "get" : action, value: extra.first)

        case "inhibit":
            return .inhibit(action: action.isEmpty ? "toggle" : action)

        case "mpris":
            return .mpris(action: action.isEmpty ? "status" : action)

        case "theme":
            switch action {
            case "set":
                if let name = extra.first { return .setTheme(name: name) }
                return .unknown("theme set missing name")
            case "list": return .listThemes
            case "toggle", "togglemode": return .toggleThemeMode
            default: return .getTheme
            }

        case "screenshot":
            if !action.isEmpty { return .screenshotMode(action) }
            return .screenshot

        case "toast":
            return .toast(level: action.isEmpty ? "info" : action, message: extra.joined(separator: " "))

        case "doctor":
            return .doctor

        case "reload":
            return .reloadConfig

        case "plugins", "plugin":
            switch action {
            case "search":
                return .searchPlugins(query: extra.joined(separator: " "))
            case "install":
                if let id = extra.first { return .installPlugin(id: id) }
                return .unknown("plugins install requires plugin id")
            case "uninstall", "remove":
                if let id = extra.first { return .uninstallPlugin(id: id) }
                return .unknown("plugins uninstall requires plugin id")
            case "enable":
                if let id = extra.first { return .enablePlugin(id: id) }
                return .unknown("plugins enable requires plugin id")
            case "disable":
                if let id = extra.first { return .disablePlugin(id: id) }
                return .unknown("plugins disable requires plugin id")
            case "lock":
                return .lockPlugins
            case "restore":
                return .restorePlugins(path: extra.first)
            case "list":
                return .listPlugins
            default:
                return .listPlugins
            }

        case "applets", "applet":
            switch action {
            case "toggle":
                if let id = extra.first { return .toggleApplet(id: id) }
                return .unknown("applets toggle requires applet id")
            case "list":
                return .listApplets
            default:
                return .listApplets
            }

        case "status":
            return .status

        case "weather":
            switch action {
            case "refresh", "reload":
                return .weatherRefresh
            case "set", "location":
                if !extra.isEmpty {
                    return .weatherSetLocation(location: extra.joined(separator: " "))
                }
                return .unknown("weather set/location requires location string")
            case "status":
                return .weatherStatus
            default:
                if !action.isEmpty {
                    let locArgs = ([action] + extra).joined(separator: " ")
                    return .weatherSetLocation(location: locArgs)
                }
                return .weatherStatus
            }

        case "island", "disland":
            return .island(action: action.isEmpty ? "toggle" : action, value: extra.first)

        case "danksearch", "dsearch":
            return .danksearch(
                action: action.isEmpty ? "status" : action,
                query: extra.isEmpty ? nil : extra.joined(separator: " ")
            )

        default:
            return .unknown(args.joined(separator: " "))
        }
    }
}
