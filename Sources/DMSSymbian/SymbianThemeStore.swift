import SwiftUI
import AppKit
import DMSCore

/// Standalone theme provider for the Nokia Belle USB Sync companion application.
@MainActor
public final class SymbianThemeStore: ObservableObject {
    public static let shared = SymbianThemeStore()

    @Published public private(set) var palette: DMSPalette

    private init() {
        let isDark = (NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? .darkAqua) == .darkAqua
        let themeName = Self.readThemeName()
        self.palette = StockThemes.theme(named: themeName, isDark: isDark)
    }

    public func refresh() {
        let isDark = (NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? .darkAqua) == .darkAqua
        let themeName = Self.readThemeName()
        self.palette = StockThemes.theme(named: themeName, isDark: isDark)
    }

    private static func readThemeName() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let settingsURL = appSupport.appendingPathComponent("DMS/settings.json")
        if let data = try? Data(contentsOf: settingsURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = obj["theme"] as? String, !name.isEmpty {
            return name
        }
        return "purple"
    }
}

public extension Color {
    init(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }
        if clean.count == 3 {
            let r = clean[clean.startIndex]
            let g = clean[clean.index(clean.startIndex, offsetBy: 1)]
            let b = clean[clean.index(clean.startIndex, offsetBy: 2)]
            clean = "\(r)\(r)\(g)\(g)\(b)\(b)"
        }
        guard clean.count >= 6, let hexNum = UInt64(clean.prefix(6), radix: 16) else {
            self = .clear
            return
        }
        let r = Double((hexNum >> 16) & 0xFF) / 255.0
        let g = Double((hexNum >> 8) & 0xFF) / 255.0
        let b = Double(hexNum & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
