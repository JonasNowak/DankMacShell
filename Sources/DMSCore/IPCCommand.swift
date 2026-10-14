import Foundation

/// IPC commands triggerable via `dms://` URLs from Raycast, Shortcuts, or Terminal.
public enum IPCCommand: Sendable, Equatable {
    case toggleLauncher
    case openLauncher
    case closeLauncher
    case toggleControlCenter
    case openControlCenter
    case closeControlCenter
    case powerMenu
    case setTheme(name: String)
    case toggleThemeMode
    case screenshot
    case reloadConfig
    case unknown(String)

    public static func parse(url: URL) -> IPCCommand? {
        guard url.scheme?.lowercased() == "dms" else { return nil }
        let host = url.host?.lowercased() ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()

        switch host {
        case "togglelauncher":
            return .toggleLauncher
        case "openlauncher":
            return .openLauncher
        case "closelauncher":
            return .closeLauncher
        case "togglecontrolcenter":
            return .toggleControlCenter
        case "opencontrolcenter":
            return .openControlCenter
        case "closecontrolcenter":
            return .closeControlCenter
        case "powermenu":
            return .powerMenu
        case "togglethememode":
            return .toggleThemeMode
        case "screenshot":
            return .screenshot
        case "reloadconfig":
            return .reloadConfig
        case "settheme":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let item = components.queryItems?.first(where: { $0.name.lowercased() == "name" }),
               let name = item.value {
                return .setTheme(name: name)
            }
            return .unknown("setTheme without name parameter")
        default:
            return .unknown(host)
        }
    }
}
