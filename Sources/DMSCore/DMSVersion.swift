import Foundation

public enum DMSVersion: Sendable {
    public static let current = "0.9.1"

    public static var displayVersion: String {
        if let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !short.isEmpty {
            return short
        }
        return current
    }

    public static var userAgent: String {
        "DankMacShell/\(current) (https://github.com/JonasNowak/DankMacShell)"
    }
}
