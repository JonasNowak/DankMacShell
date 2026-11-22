import Foundation

/// Color palette shared between the host app and the desktop widget extension.
/// Defaults match the dark purple Material 3 theme (seed `#6750A4`).
public struct DMSWidgetPalette: Codable, Sendable, Equatable {
    public var surfaceContainerHigh: String
    public var surfaceContainerHighest: String
    public var primary: String
    public var primaryContainer: String
    public var onPrimary: String
    public var onPrimaryContainer: String
    public var onSurface: String
    public var onSurfaceVariant: String
    public var outlineVariant: String
    public var isDark: Bool

    public init(
        surfaceContainerHigh: String = "#36343B",
        surfaceContainerHighest: String = "#49454F",
        primary: String = "#D0BCFF",
        primaryContainer: String = "#4F378B",
        onPrimary: String = "#381E72",
        onPrimaryContainer: String = "#EADDFF",
        onSurface: String = "#E6E0E9",
        onSurfaceVariant: String = "#CAC4D0",
        outlineVariant: String = "#49454F",
        isDark: Bool = true
    ) {
        self.surfaceContainerHigh = surfaceContainerHigh
        self.surfaceContainerHighest = surfaceContainerHighest
        self.primary = primary
        self.primaryContainer = primaryContainer
        self.onPrimary = onPrimary
        self.onPrimaryContainer = onPrimaryContainer
        self.onSurface = onSurface
        self.onSurfaceVariant = onSurfaceVariant
        self.outlineVariant = outlineVariant
        self.isDark = isDark
    }
}

/// Live system telemetry shown by the desktop widget.
public struct DMSWidgetTelemetry: Codable, Sendable, Equatable {
    public var cpuPercent: Double
    public var ramPercent: Double
    public var ramUsedGB: Double
    public var ramTotalGB: Double
    public var batteryPercent: Int
    public var isCharging: Bool
    public var hasBattery: Bool

    public init(
        cpuPercent: Double = 0,
        ramPercent: Double = 0,
        ramUsedGB: Double = 0,
        ramTotalGB: Double = 0,
        batteryPercent: Int = 100,
        isCharging: Bool = false,
        hasBattery: Bool = true
    ) {
        self.cpuPercent = cpuPercent
        self.ramPercent = ramPercent
        self.ramUsedGB = ramUsedGB
        self.ramTotalGB = ramTotalGB
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.hasBattery = hasBattery
    }
}

/// Weather summary shown by the desktop widget.
public struct DMSWidgetWeather: Codable, Sendable, Equatable {
    public var temperatureText: String
    public var condition: String
    public var sfSymbol: String
    public var location: String

    public init(
        temperatureText: String = "--°",
        condition: String = "Unknown",
        sfSymbol: String = "cloud.sun.fill",
        location: String = "Unknown"
    ) {
        self.temperatureText = temperatureText
        self.condition = condition
        self.sfSymbol = sfSymbol
        self.location = location
    }
}

/// Pomodoro timer state shown by the desktop widget.
public struct DMSWidgetPomodoro: Codable, Sendable, Equatable {
    public var isRunning: Bool
    public var isBreak: Bool
    public var phaseLabel: String
    public var endDate: Date?
    public var remainingSeconds: Int
    public var completedSessions: Int

    public init(
        isRunning: Bool = false,
        isBreak: Bool = false,
        phaseLabel: String = "Focus",
        endDate: Date? = nil,
        remainingSeconds: Int = 1500,
        completedSessions: Int = 0
    ) {
        self.isRunning = isRunning
        self.isBreak = isBreak
        self.phaseLabel = phaseLabel
        self.endDate = endDate
        self.remainingSeconds = remainingSeconds
        self.completedSessions = completedSessions
    }
}

/// Full snapshot the host app writes for the desktop widget extension to read.
public struct DMSWidgetSnapshot: Codable, Sendable, Equatable {
    public var palette: DMSWidgetPalette
    public var fontFamily: String
    public var useSingleFontEverywhere: Bool
    public var telemetry: DMSWidgetTelemetry
    public var weather: DMSWidgetWeather
    public var pomodoro: DMSWidgetPomodoro
    public var updatedAt: Date

    public init(
        palette: DMSWidgetPalette = .init(),
        fontFamily: String = "SF Pro",
        useSingleFontEverywhere: Bool = false,
        telemetry: DMSWidgetTelemetry = .init(),
        weather: DMSWidgetWeather = .init(),
        pomodoro: DMSWidgetPomodoro = .init(),
        updatedAt: Date = Date()
    ) {
        self.palette = palette
        self.fontFamily = fontFamily
        self.useSingleFontEverywhere = useSingleFontEverywhere
        self.telemetry = telemetry
        self.weather = weather
        self.pomodoro = pomodoro
        self.updatedAt = updatedAt
    }

    /// Empty snapshot used before the host app writes real data.
    public static let placeholder = DMSWidgetSnapshot(updatedAt: Date(timeIntervalSince1970: 0))
}

/// Reads and writes the widget snapshot JSON shared via the app group container.
public enum DMSWidgetSnapshotStore {
    public static let extensionBundleID = "io.github.jonasnowak.dms.widgets"

    /// URL inside the widget extension's own app group container (read by the extension).
    public static func hostSnapshotURL(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Containers/\(extensionBundleID)/Data/Library/Application Support/DMS", isDirectory: true)
            .appendingPathComponent("widget-snapshot.json")
    }

    /// URL inside the host app's own Application Support directory (written by the host).
    public static func extensionSnapshotURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("DMS", isDirectory: true).appendingPathComponent("widget-snapshot.json")
    }

    public static func write(_ snapshot: DMSWidgetSnapshot, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public static func read(from url: URL) -> DMSWidgetSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DMSWidgetSnapshot.self, from: data)
    }
}
