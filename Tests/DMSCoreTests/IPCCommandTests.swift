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

        // 7. Process List
        #expect(IPCCommand.parse(url: URL(string: "dms://processlist/open")!) == .openProcessList)
        #expect(IPCCommand.parse(url: URL(string: "dms://processlist/list")!) == .listProcesses)
        #expect(IPCCommand.parse(url: URL(string: "dms://processlist/kill?pid=12345")!) == .killProcess(pid: 12345))
        #expect(IPCCommand.parse(url: URL(string: "dms://processlist")!) == .toggleProcessList)

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

        // 11. Bar & Dock
        #expect(IPCCommand.parse(url: URL(string: "dms://bar/reveal?position=top")!) == .bar(action: "reveal", value: "top"))
        #expect(IPCCommand.parse(url: URL(string: "dms://dock/hide")!) == .dock(action: "hide", value: nil))

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

        #expect(IPCCommand.parseCLI(args: ["colorpicker", "pick"]) == .pickColor)
        #expect(IPCCommand.parseCLI(args: ["qr", "https://apple.com"]) == .generateQR(text: "https://apple.com"))

        #expect(IPCCommand.parseCLI(args: ["keybinds", "open"]) == .openKeybinds)
        #expect(IPCCommand.parseCLI(args: ["keybinds", "close"]) == .closeKeybinds)

        #expect(IPCCommand.parseCLI(args: ["settings", "dump"]) == .dumpSettings)
        #expect(IPCCommand.parseCLI(args: ["settings", "get", "theme"]) == .getSetting(key: "theme"))
        #expect(IPCCommand.parseCLI(args: ["settings", "set", "theme", "blue"]) == .setSetting(key: "theme", value: "blue"))
        #expect(IPCCommand.parseCLI(args: ["settings", "open", "dock"]) == .openSettingsTab("dock"))
        #expect(IPCCommand.parseCLI(args: ["settings", "close"]) == .closeSettings)

        #expect(IPCCommand.parseCLI(args: ["bar", "reveal", "bottom"]) == .bar(action: "reveal", value: "bottom"))
        #expect(IPCCommand.parseCLI(args: ["dock", "toggle"]) == .dock(action: "toggle", value: nil))

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
}
