import Foundation

/// Defines how DankMacShell derives the two colors for OmniWM's active window border gradient.
public enum OmniWMGradientMode: String, Codable, CaseIterable, Sendable {
    /// Primary dominant brand color to Tertiary harmonic accent (M3 Expressive +60°/+120° HCT rotation).
    case expressive = "expressive"
    /// Primary dominant color to Secondary analogous tone within the same hue family.
    case analogous = "analogous"
    /// PrimaryContainer ambient shadow to Primary high-luminance highlight (simulates directional top-left illumination).
    case luminance = "luminance"
    /// Top 2 distinct dominant color clusters extracted directly from the active desktop wallpaper.
    case dualWallpaper = "dualWallpaper"
    /// Disables gradient (`borders.gradient.enabled = false`) and applies solid primary border.
    case solid = "solid"

    public var displayName: String {
        switch self {
        case .expressive: return "Expressive (Primary → Tertiary)"
        case .analogous: return "Analogous (Primary → Secondary)"
        case .luminance: return "Luminance (Container → Primary)"
        case .dualWallpaper: return "Dual Wallpaper Seeds"
        case .solid: return "Solid Accent"
        }
    }

    public var subtitle: String {
        switch self {
        case .expressive: return "Vibrant, high-contrast iridescent flow matching M3 Expressive"
        case .analogous: return "Subtle, smooth monochromatic tonal transition"
        case .luminance: return "Directional lighting effect (ambient shadow to highlight)"
        case .dualWallpaper: return "Two dominant color clusters extracted from the wallpaper"
        case .solid: return "Single solid primary border (gradient disabled)"
        }
    }
}

/// OmniWM window border gradient direction.
public enum OmniWMGradientDirection: String, Codable, CaseIterable, Sendable {
    case topLeftToBottomRight = "topLeftToBottomRight"
    case topRightToBottomLeft = "topRightToBottomLeft"

    public var displayName: String {
        switch self {
        case .topLeftToBottomRight: return "Top-Left ↘ Bottom-Right"
        case .topRightToBottomLeft: return "Top-Right ↙ Bottom-Left"
        }
    }
}

/// Pure updater for OmniWM `settings.toml`.
public struct OmniWMThemeUpdater: Sendable {

    /// Derives the start and end colors for the gradient given the current palette and mode.
    public static func resolveColors(
        palette: ThemePalette,
        secondarySeed: M3Color? = nil,
        mode: OmniWMGradientMode
    ) -> (start: M3Color, end: M3Color, solid: M3Color, isGradient: Bool) {
        switch mode {
        case .expressive:
            return (start: palette.primary, end: palette.tertiary, solid: palette.primary, isGradient: true)
        case .analogous:
            return (start: palette.primary, end: palette.secondary, solid: palette.primary, isGradient: true)
        case .luminance:
            return (start: palette.primaryContainer, end: palette.primary, solid: palette.primary, isGradient: true)
        case .dualWallpaper:
            let endColor = secondarySeed ?? palette.tertiary
            return (start: palette.primary, end: endColor, solid: palette.primary, isGradient: true)
        case .solid:
            return (start: palette.primary, end: palette.primary, solid: palette.primary, isGradient: false)
        }
    }

    /// Surgically updates the theme-bearing sections in `settings.toml` without mutating any hotkeys, routing, or comments.
    public static func applyTheme(
        to tomlContent: String,
        palette: ThemePalette,
        secondarySeed: M3Color? = nil,
        mode: OmniWMGradientMode = .expressive,
        direction: OmniWMGradientDirection = .topLeftToBottomRight,
        syncOverview: Bool = true,
        syncWorkspaceBar: Bool = true
    ) -> String {
        let (start, end, solid, isGradient) = resolveColors(palette: palette, secondarySeed: secondarySeed, mode: mode)

        var updates: [String: [String: String]] = [:]

        // 1. [borders.color]
        updates["borders.color"] = [
            "alpha": "1.0",
            "red": String(format: "%.6f", solid.red),
            "green": String(format: "%.6f", solid.green),
            "blue": String(format: "%.6f", solid.blue)
        ]

        // 2. [borders.gradient]
        updates["borders.gradient"] = [
            "direction": "\"\(direction.rawValue)\"",
            "enabled": isGradient ? "true" : "false"
        ]

        // 3. [borders.gradient.start]
        updates["borders.gradient.start"] = [
            "alpha": "1.0",
            "red": String(format: "%.6f", start.red),
            "green": String(format: "%.6f", start.green),
            "blue": String(format: "%.6f", start.blue)
        ]

        // 4. [borders.gradient.end]
        updates["borders.gradient.end"] = [
            "alpha": "1.0",
            "red": String(format: "%.6f", end.red),
            "green": String(format: "%.6f", end.green),
            "blue": String(format: "%.6f", end.blue)
        ]

        // 5. Overview window borders
        if syncOverview {
            updates["overview.windowBorders.hovered"] = [
                "alpha": "1.0",
                "red": String(format: "%.6f", palette.tertiary.red),
                "green": String(format: "%.6f", palette.tertiary.green),
                "blue": String(format: "%.6f", palette.tertiary.blue)
            ]
            updates["overview.windowBorders.selected"] = [
                "alpha": "1.0",
                "red": String(format: "%.6f", palette.primary.red),
                "green": String(format: "%.6f", palette.primary.green),
                "blue": String(format: "%.6f", palette.primary.blue)
            ]
            updates["overview.windowBorders.normal"] = [
                "alpha": "0.5",
                "red": String(format: "%.6f", palette.outline.red),
                "green": String(format: "%.6f", palette.outline.green),
                "blue": String(format: "%.6f", palette.outline.blue)
            ]
        }

        // 6. Workspace bar accent
        if syncWorkspaceBar {
            updates["workspaceBar.accentColor"] = [
                "alpha": "1.0",
                "red": String(format: "%.6f", palette.primary.red),
                "green": String(format: "%.6f", palette.primary.green),
                "blue": String(format: "%.6f", palette.primary.blue)
            ]
        }

        return updateTOML(content: tomlContent, updates: updates)
    }

    private static func updateTOML(content: String, updates: [String: [String: String]]) -> String {
        var remainingUpdates = updates
        let lines = content.components(separatedBy: "\n")
        var outputLines: [String] = []
        var currentSection: String?
        var sectionKeysSeen = Set<String>()

        let finishSection = { (sec: String?) in
            guard let sec = sec, let keyMap = remainingUpdates[sec] else { return }
            for (k, v) in keyMap.sorted(by: { $0.key < $1.key }) {
                if !sectionKeysSeen.contains(k) {
                    outputLines.append("\(k) = \(v)")
                }
            }
            remainingUpdates.removeValue(forKey: sec)
        }

        for line in lines {
            let stripped = line.trimmingCharacters(in: .whitespaces)

            // Header line: [section] or [[array_section]]
            if stripped.hasPrefix("[") && stripped.hasSuffix("]") && !stripped.hasPrefix("[[") {
                finishSection(currentSection)
                let secName = stripped.trimmingCharacters(in: CharacterSet(charactersIn: "[] \t"))
                currentSection = secName
                sectionKeysSeen.removeAll()
                outputLines.append(line)
                continue
            } else if stripped.hasPrefix("[[") {
                finishSection(currentSection)
                currentSection = nil
                sectionKeysSeen.removeAll()
                outputLines.append(line)
                continue
            }

            if let sec = currentSection, let keyMap = remainingUpdates[sec] {
                if stripped.contains("=") && !stripped.hasPrefix("#") {
                    let parts = stripped.split(separator: "=", maxSplits: 1)
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    if let newVal = keyMap[key] {
                        outputLines.append("\(key) = \(newVal)")
                        sectionKeysSeen.insert(key)
                        continue
                    }
                }
            }

            outputLines.append(line)
        }

        finishSection(currentSection)

        // Any sections that didn't exist in the input file at all:
        for (secName, keyMap) in remainingUpdates.sorted(by: { $0.key < $1.key }) {
            outputLines.append("")
            outputLines.append("[\(secName)]")
            for (k, v) in keyMap.sorted(by: { $0.key < $1.key }) {
                outputLines.append("\(k) = \(v)")
            }
        }

        return outputLines.joined(separator: "\n")
    }
}
