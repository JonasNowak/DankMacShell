import Foundation
import Combine
import WidgetKit
import DMSCore

/// Pushes a Codable snapshot of theme, telemetry, weather, and pomodoro state into the
/// shared store that the WidgetKit extension reads, and reloads widget timelines.
///
/// Theme changes trigger a debounced full sync with timeline reload; weather and
/// telemetry changes trigger lightweight periodic syncs (timeline reload at most once
/// per 10 minutes unless forced).
@MainActor
public final class WidgetSnapshotService {
    public static let shared = WidgetSnapshotService()

    /// Minimum interval between `WidgetCenter` timeline reloads for non-forced syncs.
    private static let timelineReloadInterval: TimeInterval = 600.0
    /// Telemetry is `@Observable` (no Combine publisher), so it is synced periodically.
    private static let telemetrySyncInterval: TimeInterval = 60.0

    private var cancellables = Set<AnyCancellable>()
    private var telemetryTimer: Timer?
    private var lastTimelineReload: Date = .distantPast

    private init() {}

    public func start() {
        // Theme / typography changes -> debounced full sync with timeline reload.
        Publishers.Merge3(
            ThemeStore.shared.$palette.map { _ in () },
            ThemeStore.shared.$typographyTokens.map { _ in () },
            ThemeStore.shared.$useSingleFontEverywhere.map { _ in () }
        )
        .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.syncNow(forceReload: true)
        }
        .store(in: &cancellables)

        // Weather changes -> throttled lightweight sync.
        WeatherService.shared.$currentWeather
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.syncNow(forceReload: false)
            }
            .store(in: &cancellables)

        // Telemetry changes -> periodic lightweight sync (Observation-based service).
        telemetryTimer?.invalidate()
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: Self.telemetrySyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncNow(forceReload: false)
            }
        }

        syncNow(forceReload: true)
    }

    public func syncNow(forceReload: Bool = false) {
        let theme = ThemeStore.shared
        let palette = theme.palette
        let telemetry = TelemetryService.shared.telemetry
        let weather = WeatherService.shared.currentWeather
        let pomodoro = PomodoroService.shared
        let useFahrenheit = ConfigStore.shared.config.weatherUnits.lowercased() == "fahrenheit"
        let tempText: String = {
            if weather.locationName.isEmpty || weather.locationName == "Unknown" {
                return "--°"
            }
            let val = useFahrenheit ? weather.temperatureF : weather.temperatureC
            return "\(Int(val.rounded()))°\(useFahrenheit ? "F" : "C")"
        }()

        let snapshot = DMSWidgetSnapshot(
            palette: DMSWidgetPalette(
                surfaceContainerHigh: palette.surfaceContainerHigh.hex,
                surfaceContainerHighest: palette.surfaceContainerHighest.hex,
                primary: palette.primary.hex,
                primaryContainer: palette.primaryContainer.hex,
                onPrimary: palette.onPrimary.hex,
                onPrimaryContainer: palette.onPrimaryContainer.hex,
                onSurface: palette.onSurface.hex,
                onSurfaceVariant: palette.onSurfaceVariant.hex,
                outlineVariant: palette.outlineVariant.hex,
                isDark: palette.isDark
            ),
            fontFamily: theme.typographyTokens.fontFamilyUI,
            useSingleFontEverywhere: theme.useSingleFontEverywhere,
            telemetry: DMSWidgetTelemetry(
                cpuPercent: telemetry.cpuPercent,
                ramPercent: telemetry.ramPercent,
                ramUsedGB: telemetry.ramUsedGB,
                ramTotalGB: telemetry.ramTotalGB,
                batteryPercent: telemetry.batteryPercent ?? 100,
                isCharging: telemetry.isCharging,
                hasBattery: telemetry.batteryPercent != nil
            ),
            weather: DMSWidgetWeather(
                temperatureText: tempText,
                condition: weather.conditionDescription,
                sfSymbol: weather.sfSymbol,
                location: weather.locationName
            ),
            pomodoro: DMSWidgetPomodoro(
                isRunning: pomodoro.isRunning,
                isBreak: pomodoro.isBreak,
                phaseLabel: pomodoro.phaseLabel,
                endDate: pomodoro.endDate,
                remainingSeconds: pomodoro.remainingSeconds,
                completedSessions: pomodoro.completedSessions
            ),
            updatedAt: Date()
        )

        try? DMSWidgetSnapshotStore.write(snapshot, to: DMSWidgetSnapshotStore.hostSnapshotURL())

        if forceReload || Date().timeIntervalSince(lastTimelineReload) >= Self.timelineReloadInterval {
            lastTimelineReload = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
