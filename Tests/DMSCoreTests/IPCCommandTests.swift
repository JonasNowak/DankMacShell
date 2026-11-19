import Testing
import Foundation
@testable import DMSCore

@Suite("IPC Command Parsing Tests")
struct IPCCommandTests {

    @Test("URL Scheme Parsing for All DMS Endpoints")
    func testURLParsingAllEndpoints() {
        // 1. Launcher / Spotlight
        #expect(IPCCommand.parse(url: URL(string: "dms://launcher/open")!) == .openLauncher)
        #expect(IPCCommand.parse(url: URL(string: "dms://launcher/open?query=safari")!) == .openLauncherQuery(query: "safari"))
        #expect(IPCCommand.parse(url: URL(string: "dms://openlauncher?q=kitty")!) == .openLauncherQuery(query: "kitty"))
        #expect(IPCCommand.parse(url: URL(string: "dms://launcher/close")!) == .closeLauncher)
        #expect(IPCCommand.parse(url: URL(string: "dms://closelauncher")!) == .closeLauncher)
        #expect(IPCCommand.parse(url: URL(string: "dms://launcher")!) == .toggleLauncher)

        // 2. Control Center
        #expect(IPCCommand.parse(url: URL(string: "dms://controlcenter/open")!) == .openControlCenter)
        #expect(IPCCommand.parse(url: URL(string: "dms://controlcenter/close")!) == .closeControlCenter)
        #expect(IPCCommand.parse(url: URL(string: "dms://control-center")!) == .toggleControlCenter)

        // 3. Dash
        #expect(IPCCommand.parse(url: URL(string: "dms://dash/open")!) == .openDash)
        #expect(IPCCommand.parse(url: URL(string: "dms://dash/close")!) == .closeDash)
        #expect(IPCCommand.parse(url: URL(string: "dms://dankdash")!) == .toggleDash)

        // 4. Power Menu
        #expect(IPCCommand.parse(url: URL(string: "dms://powermenu")!) == .powerMenu)
        #expect(IPCCommand.parse(url: URL(string: "dms://powermenu/sleep")!) == .powerMenuAction("sleep"))
        #expect(IPCCommand.parse(url: URL(string: "dms://powermenu?action=lock")!) == .powerMenuAction("lock"))

        // 5. Notepad
        #expect(IPCCommand.parse(url: URL(string: "dms://notepad/open")!) == .openNotepad)
        #expect(IPCCommand.parse(url: URL(string: "dms://notepad/close")!) == .closeNotepad)
        #expect(IPCCommand.parse(url: URL(string: "dms://notepad/get")!) == .getNotepad)
        #expect(IPCCommand.parse(url: URL(string: "dms://notepad/set?text=NoteText")!) == .setNotepad(text: "NoteText"))
        #expect(IPCCommand.parse(url: URL(string: "dms://notepad/append?text=Extra")!) == .appendNotepad(text: "Extra"))
        #expect(IPCCommand.parse(url: URL(string: "dms://notepad")!) == .toggleNotepad)

        // 6. Clipboard
        #expect(IPCCommand.parse(url: URL(string: "dms://clipboard/open")!) == .openClipboard)
        #expect(IPCCommand.parse(url: URL(string: "dms://clipboard/list")!) == .listClipboard)
        #expect(IPCCommand.parse(url: URL(string: "dms://clipboard/clear")!) == .clearClipboard)
        #expect(IPCCommand.parse(url: URL(string: "dms://clipboard/copy?text=CopiedText")!) == .copyClipboard(text: "CopiedText"))
        #expect(IPCCommand.parse(url: URL(string: "dms://clipboard")!) == .toggleClipboard)

        // 7. Process List & Unhide/Hide
        #expect(IPCCommand.parse(url: URL(string: "dms://processlist/open")!) == .openProcessList)
        #expect(IPCCommand.parse(url: URL(string: "dms://processlist/list")!) == .listProcesses)
        #expect(IPCCommand.parse(url: URL(string: "dms://processlist/kill?pid=12345")!) == .killProcess(pid: 12345))
        #expect(IPCCommand.parse(url: URL(string: "dms://processlist")!) == .toggleProcessList)
        #expect(IPCCommand.parse(url: URL(string: "dms://unhide?id=com.apple.Safari")!) == .unhideApp(bundleID: "com.apple.Safari", inBackground: false))
        #expect(IPCCommand.parse(url: URL(string: "dms://unhide?id=com.apple.Safari&background=true")!) == .unhideApp(bundleID: "com.apple.Safari", inBackground: true))
        #expect(IPCCommand.parse(url: URL(string: "dms://unhideall")!) == .unhideAllApps(inBackground: false))
        #expect(IPCCommand.parse(url: URL(string: "dms://hide?id=com.apple.Safari")!) == .hideApp(bundleID: "com.apple.Safari"))
        #expect(IPCCommand.parse(url: URL(string: "dms://activate?id=com.apple.Safari")!) == .activateApp(bundleID: "com.apple.Safari"))

        // 8. Color Picker & QR
        #expect(IPCCommand.parse(url: URL(string: "dms://colorpicker/pick")!) == .pickColor)
        #expect(IPCCommand.parse(url: URL(string: "dms://colorpicker")!) == .openColorPicker)
        #expect(IPCCommand.parse(url: URL(string: "dms://qr?text=https://dms.io")!) == .generateQR(text: "https://dms.io"))
        #expect(IPCCommand.parse(url: URL(string: "dms://qr")!) == .openQR)

        // 9. Keybinds
        #expect(IPCCommand.parse(url: URL(string: "dms://keybinds/open")!) == .openKeybinds)
        #expect(IPCCommand.parse(url: URL(string: "dms://keybinds/close")!) == .closeKeybinds)
        #expect(IPCCommand.parse(url: URL(string: "dms://keybinds")!) == .toggleKeybinds)

        // 10. Settings
        #expect(IPCCommand.parse(url: URL(string: "dms://settings/open")!) == .openSettings)
        #expect(IPCCommand.parse(url: URL(string: "dms://settings/dump")!) == .dumpSettings)
        #expect(IPCCommand.parse(url: URL(string: "dms://settings?tab=theme")!) == .openSettingsTab("theme"))
        #expect(IPCCommand.parse(url: URL(string: "dms://settings?key=barMarginX")!) == .getSetting(key: "barMarginX"))
        #expect(IPCCommand.parse(url: URL(string: "dms://settings?key=theme&value=orange")!) == .setSetting(key: "theme", value: "orange"))
        #expect(IPCCommand.parse(url: URL(string: "dms://settings")!) == .toggleSettings)

        // 11. Bar & Workspace (dock URLs are unknown since the Dock subsystem was removed)
        #expect(IPCCommand.parse(url: URL(string: "dms://bar/reveal?position=top")!) == .bar(action: "reveal", value: "top"))
        #expect(IPCCommand.parse(url: URL(string: "dms://dock/hide")!) == .unknown("dms://dock/hide"))
        #expect(IPCCommand.parse(url: URL(string: "dms://workspace/switch?number=3")!) == .workspace(action: "switch", value: "3"))

        // 12. Audio, Mic, Brightness, Inhibit, Media
        #expect(IPCCommand.parse(url: URL(string: "dms://audio/setvolume?volume=80")!) == .audio(action: "setvolume", value: "80"))
        #expect(IPCCommand.parse(url: URL(string: "dms://mic/mute")!) == .mic(action: "mute", value: nil))
        #expect(IPCCommand.parse(url: URL(string: "dms://brightness/set?level=60")!) == .brightness(action: "set", value: "60"))
        #expect(IPCCommand.parse(url: URL(string: "dms://inhibit/toggle")!) == .inhibit(action: "toggle"))
        #expect(IPCCommand.parse(url: URL(string: "dms://mpris/play")!) == .mpris(action: "play"))

        // 13. Themes
        #expect(IPCCommand.parse(url: URL(string: "dms://theme/list")!) == .listThemes)
        #expect(IPCCommand.parse(url: URL(string: "dms://theme/toggle")!) == .toggleThemeMode)
        #expect(IPCCommand.parse(url: URL(string: "dms://theme/get")!) == .getTheme)

        // 14. Screenshot & Toast
        #expect(IPCCommand.parse(url: URL(string: "dms://screenshot/window")!) == .screenshotMode("window"))
        #expect(IPCCommand.parse(url: URL(string: "dms://toast?level=warn&msg=WarningMsg")!) == .toast(level: "warn", message: "WarningMsg"))

        // 15. Doctor & Config Reload
        #expect(IPCCommand.parse(url: URL(string: "dms://doctor")!) == .doctor)
        #expect(IPCCommand.parse(url: URL(string: "dms://reloadconfig")!) == .reloadConfig)
        #expect(IPCCommand.parse(url: URL(string: "dms://status")!) == .status)

        // 16. Plugins & Applets
        #expect(IPCCommand.parse(url: URL(string: "dms://plugins/install?id=github-notifications")!) == .installPlugin(id: "github-notifications"))
        #expect(IPCCommand.parse(url: URL(string: "dms://plugins/uninstall?id=test-p")!) == .uninstallPlugin(id: "test-p"))
        #expect(IPCCommand.parse(url: URL(string: "dms://plugins/enable?id=test-p")!) == .enablePlugin(id: "test-p"))
        #expect(IPCCommand.parse(url: URL(string: "dms://plugins/disable?id=test-p")!) == .disablePlugin(id: "test-p"))
        #expect(IPCCommand.parse(url: URL(string: "dms://plugins/lock")!) == .lockPlugins)
        #expect(IPCCommand.parse(url: URL(string: "dms://plugins/restore?path=/tmp/p.lock")!) == .restorePlugins(path: "/tmp/p.lock"))
        #expect(IPCCommand.parse(url: URL(string: "dms://applets/toggle?id=weather")!) == .toggleApplet(id: "weather"))
        #expect(IPCCommand.parse(url: URL(string: "dms://applets/list")!) == .listApplets)

        // 17. Weather
        #expect(IPCCommand.parse(url: URL(string: "dms://weather/refresh")!) == .weatherRefresh)
        #expect(IPCCommand.parse(url: URL(string: "dms://weather/set?location=Tokyo")!) == .weatherSetLocation(location: "Tokyo"))
        #expect(IPCCommand.parse(url: URL(string: "dms://weather/set?location=auto")!) == .weatherSetLocation(location: "auto"))
        #expect(IPCCommand.parse(url: URL(string: "dms://weather/set?location=52.52,%2013.405")!) == .weatherSetLocation(location: "52.52, 13.405"))
        #expect(IPCCommand.parse(url: URL(string: "dms://weather/location?q=Berlin")!) == .weatherSetLocation(location: "Berlin"))
        #expect(IPCCommand.parse(url: URL(string: "dms://weather/location?q=Tokyo,%20Japan")!) == .weatherSetLocation(location: "Tokyo, Japan"))
        #expect(IPCCommand.parse(url: URL(string: "dms://weather")!) == .weatherStatus)

        // 18. Scheme validation
        #expect(IPCCommand.parse(url: URL(string: "http://dms.io/toggle")!) == nil)
        #expect(IPCCommand.parse(url: URL(string: "file:///tmp/test")!) == nil)
    }

    @Test("CLI IPC Parsing with and without Subcommand Prefixes")
    func testCLIParsingAllCommands() {
        // Stripping 'ipc' and 'call'
        #expect(IPCCommand.parseCLI(args: ["ipc", "call", "launcher", "open"]) == .openLauncher)
        #expect(IPCCommand.parseCLI(args: ["ipc", "call", "launcher", "close"]) == .closeLauncher)
        #expect(IPCCommand.parseCLI(args: ["ipc", "call", "launcher", "openquery", "Calculator"]) == .openLauncherQuery(query: "Calculator"))

        // Direct target invocations
        #expect(IPCCommand.parseCLI(args: ["control-center", "open"]) == .openControlCenter)
        #expect(IPCCommand.parseCLI(args: ["control-center", "close"]) == .closeControlCenter)
        #expect(IPCCommand.parseCLI(args: ["dash", "open"]) == .openDash)
        #expect(IPCCommand.parseCLI(args: ["dash", "close"]) == .closeDash)

        #expect(IPCCommand.parseCLI(args: ["powermenu", "restart"]) == .powerMenuAction("restart"))
        #expect(IPCCommand.parseCLI(args: ["powermenu"]) == .powerMenu)

        #expect(IPCCommand.parseCLI(args: ["notepad", "set", "My", "New", "Note"]) == .setNotepad(text: "My New Note"))
        #expect(IPCCommand.parseCLI(args: ["notepad", "append", "Second", "Line"]) == .appendNotepad(text: "Second Line"))
        #expect(IPCCommand.parseCLI(args: ["notepad", "open"]) == .openNotepad)
        #expect(IPCCommand.parseCLI(args: ["notepad", "close"]) == .closeNotepad)

        #expect(IPCCommand.parseCLI(args: ["clipboard", "list"]) == .listClipboard)
        #expect(IPCCommand.parseCLI(args: ["clipboard", "clear"]) == .clearClipboard)
        #expect(IPCCommand.parseCLI(args: ["clipboard", "copy", "Snippet", "123"]) == .copyClipboard(text: "Snippet 123"))
        #expect(IPCCommand.parseCLI(args: ["clipboard", "open"]) == .openClipboard)

        #expect(IPCCommand.parseCLI(args: ["processlist", "list"]) == .listProcesses)
        #expect(IPCCommand.parseCLI(args: ["processlist", "kill", "9876"]) == .killProcess(pid: 9876))
        #expect(IPCCommand.parseCLI(args: ["processlist", "open"]) == .openProcessList)
        #expect(IPCCommand.parseCLI(args: ["unhide", "com.apple.Safari"]) == .unhideApp(bundleID: "com.apple.Safari", inBackground: false))
        #expect(IPCCommand.parseCLI(args: ["unhide", "com.apple.Safari", "--background"]) == .unhideApp(bundleID: "com.apple.Safari", inBackground: true))
        #expect(IPCCommand.parseCLI(args: ["unhide-all"]) == .unhideAllApps(inBackground: false))
        #expect(IPCCommand.parseCLI(args: ["unhide-all", "--background"]) == .unhideAllApps(inBackground: true))
        #expect(IPCCommand.parseCLI(args: ["hide", "com.apple.Safari"]) == .hideApp(bundleID: "com.apple.Safari"))
        #expect(IPCCommand.parseCLI(args: ["activate", "com.apple.Safari"]) == .activateApp(bundleID: "com.apple.Safari"))

        #expect(IPCCommand.parseCLI(args: ["colorpicker", "pick"]) == .pickColor)
        #expect(IPCCommand.parseCLI(args: ["qr", "https://apple.com"]) == .generateQR(text: "https://apple.com"))

        #expect(IPCCommand.parseCLI(args: ["keybinds", "open"]) == .openKeybinds)
        #expect(IPCCommand.parseCLI(args: ["keybinds", "close"]) == .closeKeybinds)

        #expect(IPCCommand.parseCLI(args: ["settings", "dump"]) == .dumpSettings)
        #expect(IPCCommand.parseCLI(args: ["settings", "get", "theme"]) == .getSetting(key: "theme"))
        #expect(IPCCommand.parseCLI(args: ["settings", "set", "theme", "blue"]) == .setSetting(key: "theme", value: "blue"))
        #expect(IPCCommand.parseCLI(args: ["settings", "open", "launcher"]) == .openSettingsTab("launcher"))
        #expect(IPCCommand.parseCLI(args: ["settings", "close"]) == .closeSettings)

        #expect(IPCCommand.parseCLI(args: ["bar", "reveal", "bottom"]) == .bar(action: "reveal", value: "bottom"))
        // "dock" is no longer a CLI target; it parses as unknown
        #expect(IPCCommand.parseCLI(args: ["dock", "toggle"]) == .unknown("dock toggle"))
        #expect(!IPCCommand.cliTargets.contains("dock"))
        #expect(IPCCommand.parseCLI(args: ["workspace", "status"]) == .workspace(action: "status", value: nil))
        #expect(IPCCommand.parseCLI(args: ["workspace", "switch", "2"]) == .workspace(action: "switch", value: "2"))

        #expect(IPCCommand.parseCLI(args: ["mic", "mute"]) == .mic(action: "mute", value: nil))
        #expect(IPCCommand.parseCLI(args: ["brightness", "set", "75"]) == .brightness(action: "set", value: "75"))
        #expect(IPCCommand.parseCLI(args: ["mpris", "pause"]) == .mpris(action: "pause"))

        #expect(IPCCommand.parseCLI(args: ["theme", "set", "orange"]) == .setTheme(name: "orange"))
        #expect(IPCCommand.parseCLI(args: ["theme", "list"]) == .listThemes)
        #expect(IPCCommand.parseCLI(args: ["theme", "toggle"]) == .toggleThemeMode)

        #expect(IPCCommand.parseCLI(args: ["screenshot", "full"]) == .screenshotMode("full"))
        #expect(IPCCommand.parseCLI(args: ["toast", "error", "Disk", "Full"]) == .toast(level: "error", message: "Disk Full"))
        #expect(IPCCommand.parseCLI(args: ["reload"]) == .reloadConfig)

        #expect(IPCCommand.parseCLI(args: ["plugins", "install", "pomodoro"]) == .installPlugin(id: "pomodoro"))
        #expect(IPCCommand.parseCLI(args: ["plugins", "uninstall", "pomodoro"]) == .uninstallPlugin(id: "pomodoro"))
        #expect(IPCCommand.parseCLI(args: ["plugins", "enable", "pomodoro"]) == .enablePlugin(id: "pomodoro"))
        #expect(IPCCommand.parseCLI(args: ["plugins", "disable", "pomodoro"]) == .disablePlugin(id: "pomodoro"))
        #expect(IPCCommand.parseCLI(args: ["plugins", "lock"]) == .lockPlugins)
        #expect(IPCCommand.parseCLI(args: ["plugins", "restore"]) == .restorePlugins(path: nil))
        #expect(IPCCommand.parseCLI(args: ["plugins", "list"]) == .listPlugins)

        #expect(IPCCommand.parseCLI(args: ["applets", "list"]) == .listApplets)

        #expect(IPCCommand.parseCLI(args: ["weather", "refresh"]) == .weatherRefresh)
        #expect(IPCCommand.parseCLI(args: ["weather", "location", "Tokyo"]) == .weatherSetLocation(location: "Tokyo"))
        #expect(IPCCommand.parseCLI(args: ["weather", "location", "auto"]) == .weatherSetLocation(location: "auto"))
        #expect(IPCCommand.parseCLI(args: ["weather", "set", "San", "Francisco"]) == .weatherSetLocation(location: "San Francisco"))
        #expect(IPCCommand.parseCLI(args: ["weather", "location", "52.52,", "13.405"]) == .weatherSetLocation(location: "52.52, 13.405"))
        #expect(IPCCommand.parseCLI(args: ["weather", "location", "-33.8688,", "151.2093"]) == .weatherSetLocation(location: "-33.8688, 151.2093"))
        #expect(IPCCommand.parseCLI(args: ["weather", "status"]) == .weatherStatus)

        // Empty args defaults to .status
        #expect(IPCCommand.parseCLI(args: []) == .status)
    }

    @Test("CLI Parsing for v0.7 dmenu / listen / shell")
    func testCLIParsingDMenuListenShell() {
        // dmenu with explicit request ID, prompt and staged candidates file
        #expect(IPCCommand.parseCLI(args: ["dmenu", "ABC123", "--prompt", "Pick one", "--file", "/tmp/x.txt"])
                == .dmenu(requestID: "ABC123", prompt: "Pick one", candidatesFile: "/tmp/x.txt"))
        // short flags
        #expect(IPCCommand.parseCLI(args: ["dmenu", "REQ", "-p", "Choose", "-f", "/tmp/y.txt"])
                == .dmenu(requestID: "REQ", prompt: "Choose", candidatesFile: "/tmp/y.txt"))
        // prompt with multiple words, no file
        #expect(IPCCommand.parseCLI(args: ["dmenu", "REQ2", "--prompt", "Pick", "a", "line"])
                == .dmenu(requestID: "REQ2", prompt: "Pick a line", candidatesFile: ""))
        // no request ID -> a fresh one is generated
        let generated = IPCCommand.parseCLI(args: ["dmenu"])
        if case .dmenu(let requestID, let prompt, let file) = generated {
            #expect(!requestID.isEmpty)
            #expect(prompt.isEmpty)
            #expect(file.isEmpty)
        } else {
            Issue.record("expected .dmenu, got \(generated)")
        }
        // also reachable through the `ipc call` prefix
        #expect(IPCCommand.parseCLI(args: ["ipc", "call", "listen", "events.audio"]) == .listen(topic: "events.audio"))

        // listen defaults to the wildcard topic
        #expect(IPCCommand.parseCLI(args: ["listen"]) == .listen(topic: "*"))
        #expect(IPCCommand.parseCLI(args: ["listen", "events.audio"]) == .listen(topic: "events.audio"))
        #expect(IPCCommand.parseCLI(args: ["listen", "events.theme"]) == .listen(topic: "events.theme"))

        // shell REPL
        #expect(IPCCommand.parseCLI(args: ["shell"]) == .shell)
    }

    @Test("CLI completion vocabulary covers dmenu / listen / shell")
    func testCLIVocabulary() {
        #expect(IPCCommand.cliTargets.contains("dmenu"))
        #expect(IPCCommand.cliTargets.contains("listen"))
        #expect(IPCCommand.cliTargets.contains("shell"))
        #expect(IPCCommand.cliActions(for: "listen").contains("events.media"))
        #expect(IPCCommand.cliActions(for: "listen").contains("events.theme"))
        #expect(IPCCommand.cliActions(for: "dmenu").contains("--prompt"))

        let dmenuCompletions = IPCCommand.cliCompletions(forPrefix: "dm")
        #expect(dmenuCompletions.contains("dmenu"))
        #expect(!dmenuCompletions.contains("listen"))
        #expect(IPCCommand.cliCompletions(forPrefix: "da").contains("danksearch"))

        let listenCompletions = IPCCommand.cliCompletions(forPrefix: "events.")
        #expect(listenCompletions.contains("events.audio"))
        #expect(listenCompletions.contains("events.theme"))

        // Empty prefix returns the whole vocabulary.
        #expect(IPCCommand.cliCompletions(forPrefix: "") == IPCCommand.cliVocabulary)
        #expect(IPCCommand.cliVocabulary.contains("shell"))
    }

    // MARK: - dms:// URL scheme security allowlist

    @Test("dms:// allowlist permits only safe UI navigation/toggle commands")
    func testURLSchemeAllowlistAllows() {
        // Launcher / dash / control center / keybinds
        #expect(IPCCommand.openLauncher.isAllowedFromURLScheme)
        #expect(IPCCommand.closeLauncher.isAllowedFromURLScheme)
        #expect(IPCCommand.toggleLauncher.isAllowedFromURLScheme)
        #expect(IPCCommand.openLauncherQuery(query: "safari").isAllowedFromURLScheme)
        #expect(IPCCommand.openDash.isAllowedFromURLScheme)
        #expect(IPCCommand.closeDash.isAllowedFromURLScheme)
        #expect(IPCCommand.toggleDash.isAllowedFromURLScheme)
        #expect(IPCCommand.openDashTab(tab: "overview").isAllowedFromURLScheme)
        #expect(IPCCommand.openControlCenter.isAllowedFromURLScheme)
        #expect(IPCCommand.closeControlCenter.isAllowedFromURLScheme)
        #expect(IPCCommand.toggleControlCenter.isAllowedFromURLScheme)
        #expect(IPCCommand.openKeybinds.isAllowedFromURLScheme)
        #expect(IPCCommand.closeKeybinds.isAllowedFromURLScheme)
        #expect(IPCCommand.toggleKeybinds.isAllowedFromURLScheme)
        // Settings open/close/toggle (never set/get/dump)
        #expect(IPCCommand.openSettings.isAllowedFromURLScheme)
        #expect(IPCCommand.closeSettings.isAllowedFromURLScheme)
        #expect(IPCCommand.toggleSettings.isAllowedFromURLScheme)
        #expect(IPCCommand.openSettingsTab("theme").isAllowedFromURLScheme)
        // DankBar toggle/reveal/hide
        #expect(IPCCommand.bar(action: "toggle").isAllowedFromURLScheme)
        #expect(IPCCommand.bar(action: "reveal").isAllowedFromURLScheme)
        #expect(IPCCommand.bar(action: "hide").isAllowedFromURLScheme)
        // Dynamic Island toggle/open/close/expand/collapse
        #expect(IPCCommand.island(action: "toggle").isAllowedFromURLScheme)
        #expect(IPCCommand.island(action: "open").isAllowedFromURLScheme)
        #expect(IPCCommand.island(action: "close").isAllowedFromURLScheme)
        #expect(IPCCommand.island(action: "expand").isAllowedFromURLScheme)
        #expect(IPCCommand.island(action: "collapse").isAllowedFromURLScheme)
        // Power menu open/toggle only
        #expect(IPCCommand.powerMenu.isAllowedFromURLScheme)
        #expect(IPCCommand.powerMenuAction("open").isAllowedFromURLScheme)
        #expect(IPCCommand.powerMenuAction("toggle").isAllowedFromURLScheme)
        // Notepad / clipboard / process list open/close/toggle only
        #expect(IPCCommand.openNotepad.isAllowedFromURLScheme)
        #expect(IPCCommand.closeNotepad.isAllowedFromURLScheme)
        #expect(IPCCommand.toggleNotepad.isAllowedFromURLScheme)
        #expect(IPCCommand.openClipboard.isAllowedFromURLScheme)
        #expect(IPCCommand.closeClipboard.isAllowedFromURLScheme)
        #expect(IPCCommand.toggleClipboard.isAllowedFromURLScheme)
        #expect(IPCCommand.openProcessList.isAllowedFromURLScheme)
        #expect(IPCCommand.closeProcessList.isAllowedFromURLScheme)
        #expect(IPCCommand.toggleProcessList.isAllowedFromURLScheme)
        // Color picker open, QR open, wallpaper picker
        #expect(IPCCommand.openColorPicker.isAllowedFromURLScheme)
        #expect(IPCCommand.openQR.isAllowedFromURLScheme)
        #expect(IPCCommand.wallpaper(action: "picker").isAllowedFromURLScheme)
    }

    @Test("dms:// allowlist denies destructive, mutating, or data-exposing commands")
    func testURLSchemeAllowlistDenies() {
        // powerMenu lock/sleep/restart/shutdown/logout
        for act in ["lock", "sleep", "restart", "shutdown", "logout"] {
            #expect(!IPCCommand.powerMenuAction(act).isAllowedFromURLScheme, "powerMenuAction(\(act)) must be denied")
        }
        // settings set/get/dump
        #expect(!IPCCommand.setSetting(key: "theme", value: "blue").isAllowedFromURLScheme)
        #expect(!IPCCommand.getSetting(key: "theme").isAllowedFromURLScheme)
        #expect(!IPCCommand.dumpSettings.isAllowedFromURLScheme)
        // clipboard copy/clear/list
        #expect(!IPCCommand.copyClipboard(text: "x").isAllowedFromURLScheme)
        #expect(!IPCCommand.clearClipboard.isAllowedFromURLScheme)
        #expect(!IPCCommand.listClipboard.isAllowedFromURLScheme)
        // notepad set/append/get
        #expect(!IPCCommand.setNotepad(text: "x").isAllowedFromURLScheme)
        #expect(!IPCCommand.appendNotepad(text: "x").isAllowedFromURLScheme)
        #expect(!IPCCommand.getNotepad.isAllowedFromURLScheme)
        // processList kill/list
        #expect(!IPCCommand.killProcess(pid: 1).isAllowedFromURLScheme)
        #expect(!IPCCommand.listProcesses.isAllowedFromURLScheme)
        // colorPicker pick, QR generate
        #expect(!IPCCommand.pickColor.isAllowedFromURLScheme)
        #expect(!IPCCommand.generateQR(text: "x").isAllowedFromURLScheme)
        // wallpaper set/next/prev/random
        #expect(!IPCCommand.wallpaper(action: "set", path: "/tmp/x.png").isAllowedFromURLScheme)
        #expect(!IPCCommand.wallpaper(action: "next").isAllowedFromURLScheme)
        #expect(!IPCCommand.wallpaper(action: "prev").isAllowedFromURLScheme)
        #expect(!IPCCommand.wallpaper(action: "random").isAllowedFromURLScheme)
        // bar / island actions outside the allowlist
        #expect(!IPCCommand.bar(action: "setposition", value: "top").isAllowedFromURLScheme)
        #expect(!IPCCommand.island(action: "status").isAllowedFromURLScheme)
        // screenshot, plugins, applets, symbian
        #expect(!IPCCommand.screenshot.isAllowedFromURLScheme)
        #expect(!IPCCommand.screenshotMode("full").isAllowedFromURLScheme)
        #expect(!IPCCommand.listPlugins.isAllowedFromURLScheme)
        #expect(!IPCCommand.installPlugin(id: "x").isAllowedFromURLScheme)
        #expect(!IPCCommand.listApplets.isAllowedFromURLScheme)
        #expect(!IPCCommand.symbian(action: "status").isAllowedFromURLScheme)
        // mic, audio, brightness, inhibit, omniwm
        #expect(!IPCCommand.mic(action: "mute").isAllowedFromURLScheme)
        #expect(!IPCCommand.audio(action: "mute").isAllowedFromURLScheme)
        #expect(!IPCCommand.brightness(action: "set", value: "50").isAllowedFromURLScheme)
        #expect(!IPCCommand.inhibit(action: "toggle").isAllowedFromURLScheme)
        #expect(!IPCCommand.omniwmTheme(action: "sync").isAllowedFromURLScheme)
        // theme set / toggle-mode
        #expect(!IPCCommand.setTheme(name: "blue").isAllowedFromURLScheme)
        #expect(!IPCCommand.toggleThemeMode.isAllowedFromURLScheme)
        // dmenu, reloadConfig, toast
        #expect(!IPCCommand.dmenu(requestID: DMenuStaging.newRequestID(), prompt: "", candidatesFile: "").isAllowedFromURLScheme)
        #expect(!IPCCommand.reloadConfig.isAllowedFromURLScheme)
        #expect(!IPCCommand.toast(level: "info", message: "hi").isAllowedFromURLScheme)
        // hide / unhide / activate / unhide-all
        #expect(!IPCCommand.hideApp(bundleID: "com.apple.Safari").isAllowedFromURLScheme)
        #expect(!IPCCommand.unhideApp(bundleID: "com.apple.Safari", inBackground: false).isAllowedFromURLScheme)
        #expect(!IPCCommand.unhideAllApps(inBackground: false).isAllowedFromURLScheme)
        #expect(!IPCCommand.activateApp(bundleID: "com.apple.Safari").isAllowedFromURLScheme)
        // mpris, lyrics, weather, wellbeing, danksearch
        #expect(!IPCCommand.mpris(action: "play").isAllowedFromURLScheme)
        #expect(!IPCCommand.lyrics(action: "status").isAllowedFromURLScheme)
        #expect(!IPCCommand.weatherStatus.isAllowedFromURLScheme)
        #expect(!IPCCommand.weatherSetLocation(location: "Berlin").isAllowedFromURLScheme)
        #expect(!IPCCommand.wellbeing(action: "status").isAllowedFromURLScheme)
        #expect(!IPCCommand.danksearch(action: "status").isAllowedFromURLScheme)
        // read-only but not on the allowlist
        #expect(!IPCCommand.status.isAllowedFromURLScheme)
        #expect(!IPCCommand.doctor.isAllowedFromURLScheme)
        #expect(!IPCCommand.unknown("x").isAllowedFromURLScheme)
    }

    // MARK: - CLI parsing regressions (v0.9.0)

    @Test("CLI parsing: theme toggle-mode, case preservation, multi-word values")
    func testCLIParsingRegressions() {
        // theme toggle-mode (all spellings)
        #expect(IPCCommand.parseCLI(args: ["theme", "toggle-mode"]) == .toggleThemeMode)
        #expect(IPCCommand.parseCLI(args: ["theme", "toggleMode"]) == .toggleThemeMode)
        #expect(IPCCommand.parseCLI(args: ["theme", "toggle"]) == .toggleThemeMode)

        // Case preservation for qr / wallpaper / weather (rawAction, not lowercased action)
        #expect(IPCCommand.parseCLI(args: ["qr", "HTTPS://Example.COM/Path?X=1"]) == .generateQR(text: "HTTPS://Example.COM/Path?X=1"))
        #expect(IPCCommand.parseCLI(args: ["wallpaper", "/Users/Me/My Photo.PNG"]) == .wallpaper(action: "set", path: "/Users/Me/My Photo.PNG"))
        #expect(IPCCommand.parseCLI(args: ["wallpaper", "set", "/Users/Me/My Photo.PNG"]) == .wallpaper(action: "set", path: "/Users/Me/My Photo.PNG"))
        #expect(IPCCommand.parseCLI(args: ["weather", "San", "Francisco"]) == .weatherSetLocation(location: "San Francisco"))
        #expect(IPCCommand.parseCLI(args: ["weather", "New", "York", "City"]) == .weatherSetLocation(location: "New York City"))

        // Multi-word settings set value: `settings set <key> <value...>`
        #expect(IPCCommand.parseCLI(args: ["settings", "set", "greeting", "Hello", "World"]) == .setSetting(key: "greeting", value: "Hello World"))
        #expect(IPCCommand.parseCLI(args: ["settings", "set", "theme", "blue"]) == .setSetting(key: "theme", value: "blue"))

        // Multi-word audio set-device name: `audio set-device <name...>`
        #expect(IPCCommand.parseCLI(args: ["audio", "set-device", "MacBook", "Pro", "Speakers"]) == .audio(action: "set-device", value: "MacBook Pro Speakers"))
        #expect(IPCCommand.parseCLI(args: ["audio", "setvolume", "80"]) == .audio(action: "setvolume", value: "80"))
    }

    // MARK: - DMenuStaging request ID validation & result whitespace

    @Test("DMenuStaging.isValidRequestID accepts only 32 uppercase hex chars")
    func testDMenuRequestIDValidation() {
        #expect(DMenuStaging.isValidRequestID(DMenuStaging.newRequestID()))
        #expect(DMenuStaging.isValidRequestID("ABCDEF0123456789ABCDEF0123456789"))
        #expect(DMenuStaging.isValidRequestID("0123456789ABCDEF0123456789ABCDEF"))
        // lowercase hex is rejected (IDs are uppercase-only)
        #expect(!DMenuStaging.isValidRequestID("abcdef0123456789abcdef0123456789"))
        // wrong lengths
        #expect(!DMenuStaging.isValidRequestID(""))
        #expect(!DMenuStaging.isValidRequestID("ABCDEF0123456789ABCDEF012345678"))    // 31
        #expect(!DMenuStaging.isValidRequestID("ABCDEF0123456789ABCDEF01234567890"))  // 33
        // non-hex characters
        #expect(!DMenuStaging.isValidRequestID("GABCDEF0123456789ABCDEF012345678"))
        #expect(!DMenuStaging.isValidRequestID("ABCDEF0123456789ABCDEF01234567-"))
        // path traversal attempts
        #expect(!DMenuStaging.isValidRequestID("../../etc/passwd"))
        #expect(!DMenuStaging.isValidRequestID("..%2F..%2Fetc%2Fpasswd0000000000"))
        #expect(!DMenuStaging.isValidRequestID("/tmp/evil"))
    }

    @Test("DMenuStaging readResult strips only trailing CR/LF and preserves whitespace")
    func testDMenuReadResultWhitespace() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dms_dmenu_ws_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let requestID = DMenuStaging.newRequestID()
        let resultURL = DMenuStaging.resultPath(for: requestID, in: dir)

        // Trailing newline stripped; leading/trailing spaces preserved.
        try "  padded selection  \n".write(to: resultURL, atomically: true, encoding: .utf8)
        #expect(DMenuStaging.readResult(for: requestID, in: dir) == "  padded selection  ")

        // CRLF stripped.
        try "line\r\n".write(to: resultURL, atomically: true, encoding: .utf8)
        #expect(DMenuStaging.readResult(for: requestID, in: dir) == "line")

        // Multiple trailing newlines stripped; inner whitespace kept.
        try "a b\tc\n\n".write(to: resultURL, atomically: true, encoding: .utf8)
        #expect(DMenuStaging.readResult(for: requestID, in: dir) == "a b\tc")

        // No trailing newline: content returned verbatim.
        try "verbatim".write(to: resultURL, atomically: true, encoding: .utf8)
        #expect(DMenuStaging.readResult(for: requestID, in: dir) == "verbatim")

        try? FileManager.default.removeItem(at: dir)
    }

    @Test("DMenuStaging works with spaces in the staging path (Application Support)")
    func testDMenuStagingSpaceInPath() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dms dmenu space test \(UUID().uuidString)", isDirectory: true)
        let requestID = DMenuStaging.newRequestID()
        let candidates = ["first candidate", "second candidate with  spaces", "third"]

        let staged = try DMenuStaging.stage(candidates: candidates, requestID: requestID, in: dir)
        #expect(staged.path.contains(" "))
        #expect(DMenuStaging.candidatesPath(for: requestID, in: dir).path == staged.path)
        #expect(DMenuStaging.readCandidates(at: staged) == candidates)

        DMenuStaging.cleanup(requestID: requestID, in: dir)
        #expect(!FileManager.default.fileExists(atPath: staged.path))
        try? FileManager.default.removeItem(at: dir)
    }
}
