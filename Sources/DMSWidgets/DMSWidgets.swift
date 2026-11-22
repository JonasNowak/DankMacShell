import SwiftUI
import WidgetKit
import DMSCore

// MARK: - Palette & Font Helpers

// The widget extension only depends on DMSCore, so it carries its own tiny
// hex parser instead of reusing the one in the main DMS target.
private extension Color {
    /// Parses `#RRGGBB` / `#RRGGBBAA` hex strings (the format DMS M3 palettes use).
    init(dmsHex: String) {
        var hex = dmsHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        let value = UInt64(hex, radix: 16)
        switch hex.count {
        case 6:
            let rgb = value ?? 0
            self.init(.sRGB,
                      red: Double((rgb >> 16) & 0xFF) / 255.0,
                      green: Double((rgb >> 8) & 0xFF) / 255.0,
                      blue: Double(rgb & 0xFF) / 255.0,
                      opacity: 1.0)
        case 8:
            let rgba = value ?? 0
            self.init(.sRGB,
                      red: Double((rgba >> 24) & 0xFF) / 255.0,
                      green: Double((rgba >> 16) & 0xFF) / 255.0,
                      blue: Double((rgba >> 8) & 0xFF) / 255.0,
                      opacity: Double(rgba & 0xFF) / 255.0)
        default:
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1.0)
        }
    }
}

/// Resolves the snapshot font family, falling back to the system font for
/// "System" / "SF Pro" / empty so widgets always render even without a custom font.
private func widgetFont(size: CGFloat, weight: Font.Weight = .regular, mono: Bool = false, snapshot: DMSWidgetSnapshot) -> Font {
    let family = snapshot.fontFamily.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = family.lowercased()
    if lower.isEmpty || lower == "system" || lower == "sf pro" {
        return .system(size: size, weight: weight, design: mono ? .monospaced : .default)
    }
    if mono && (lower == "sf mono" || lower == "monospace") {
        return .system(size: size, weight: weight, design: .monospaced)
    }
    if lower == "sf pro rounded" || lower == "rounded" {
        return .system(size: size, weight: weight, design: .rounded)
    }
    if lower == "new york" || lower == "serif" {
        return .system(size: size, weight: weight, design: .serif)
    }
    return .custom(family, size: size).weight(weight)
}

private func mmss(_ seconds: Int) -> String {
    let clamped = max(0, seconds)
    return String(format: "%02d:%02d", clamped / 60, clamped % 60)
}

// MARK: - Timeline

struct DMSWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DMSWidgetSnapshot
}

struct DMSWidgetProvider: TimelineProvider {
    func loadSnapshot() -> DMSWidgetSnapshot {
        DMSWidgetSnapshotStore.read(from: DMSWidgetSnapshotStore.extensionSnapshotURL()) ?? .placeholder
    }

    func placeholder(in context: Context) -> DMSWidgetEntry {
        DMSWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DMSWidgetEntry) -> Void) {
        completion(DMSWidgetEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DMSWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = loadSnapshot()
        var entries = [DMSWidgetEntry(date: now, snapshot: snapshot)]
        // When a Pomodoro is running, add an entry at its end date with
        // isRunning = false so the widget cleanly flips to "Done" at 00:00.
        if snapshot.pomodoro.isRunning, let end = snapshot.pomodoro.endDate, end > now {
            var doneSnapshot = snapshot
            doneSnapshot.pomodoro.isRunning = false
            entries.append(DMSWidgetEntry(date: end, snapshot: doneSnapshot))
        }
        let reloadDate = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: entries, policy: .after(reloadDate)))
    }
}

// MARK: - Shared Building Blocks

private struct PillBar: View {
    let label: String
    let value: String
    let fraction: Double
    let charging: Bool
    let snapshot: DMSWidgetSnapshot

    init(label: String, value: String, fraction: Double, charging: Bool = false, snapshot: DMSWidgetSnapshot) {
        self.label = label
        self.value = value
        self.fraction = fraction
        self.charging = charging
        self.snapshot = snapshot
    }

    var body: some View {
        let palette = snapshot.palette
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(widgetFont(size: 11, weight: .semibold, snapshot: snapshot))
                    .foregroundStyle(Color(dmsHex: palette.onSurfaceVariant))
                Spacer()
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(dmsHex: palette.primary))
                }
                Text(value)
                    .font(widgetFont(size: 11, weight: .bold, mono: true, snapshot: snapshot))
                    .monospacedDigit()
                    .foregroundStyle(Color(dmsHex: palette.onSurface))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(dmsHex: palette.surfaceContainerHighest))
                    Capsule()
                        .fill(Color(dmsHex: palette.primary))
                        .frame(width: geo.size.width * CGFloat(min(max(fraction, 0), 1)))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct WeatherCard: View {
    let weather: DMSWidgetWeather
    let snapshot: DMSWidgetSnapshot

    var body: some View {
        let palette = snapshot.palette
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: weather.sfSymbol.isEmpty ? "cloud.sun" : weather.sfSymbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(dmsHex: palette.primary))
            Text(weather.temperatureText)
                .font(widgetFont(size: 20, weight: .bold, snapshot: snapshot))
                .foregroundStyle(Color(dmsHex: palette.onSurface))
            Text(weather.condition)
                .font(widgetFont(size: 11, weight: .medium, snapshot: snapshot))
                .foregroundStyle(Color(dmsHex: palette.onSurfaceVariant))
            Text(weather.location)
                .font(widgetFont(size: 10, snapshot: snapshot))
                .foregroundStyle(Color(dmsHex: palette.outlineVariant))
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(dmsHex: palette.surfaceContainerHighest))
        )
    }
}

// MARK: - Material Clock

struct DMSClockWidget: Widget {
    let kind: String = "DMSClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DMSWidgetProvider()) { entry in
            DMSClockWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(dmsHex: entry.snapshot.palette.surfaceContainerHigh)
                }
        }
        .configurationDisplayName("Material Clock")
        .description("Live digital clock and date styled with your active DankMacShell Material 3 palette and font.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct DMSClockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DMSWidgetEntry

    var body: some View {
        let snapshot = entry.snapshot
        let palette = snapshot.palette
        if family == .systemMedium {
            HStack(spacing: 12) {
                clockColumn(snapshot: snapshot, palette: palette, timeSize: 40)
                Spacer()
                if !snapshot.weather.temperatureText.isEmpty {
                    VStack(spacing: 2) {
                        Image(systemName: snapshot.weather.sfSymbol.isEmpty ? "cloud.sun" : snapshot.weather.sfSymbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(dmsHex: palette.primary))
                        Text(snapshot.weather.temperatureText)
                            .font(widgetFont(size: 16, weight: .bold, snapshot: snapshot))
                            .foregroundStyle(Color(dmsHex: palette.onSurface))
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(dmsHex: palette.surfaceContainerHighest))
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            clockColumn(snapshot: snapshot, palette: palette, timeSize: 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func clockColumn(snapshot: DMSWidgetSnapshot, palette: DMSWidgetPalette, timeSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.date, style: .time)
                .font(widgetFont(size: timeSize, weight: .bold, snapshot: snapshot))
                .monospacedDigit()
                .foregroundStyle(Color(dmsHex: palette.onSurface))
            Text(entry.date, format: .dateTime.weekday(.wide).month().day())
                .font(widgetFont(size: 13, weight: .medium, snapshot: snapshot))
                .foregroundStyle(Color(dmsHex: palette.onSurfaceVariant))
        }
    }
}

// MARK: - System & Weather

struct DMSSystemWidget: Widget {
    let kind: String = "DMSSystemWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DMSWidgetProvider()) { entry in
            DMSSystemWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(dmsHex: entry.snapshot.palette.surfaceContainerHigh)
                }
        }
        .configurationDisplayName("System & Weather")
        .description("CPU, RAM, battery, and weather snapshot synced with your active DankMacShell theme.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct DMSSystemWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DMSWidgetEntry

    var body: some View {
        let snapshot = entry.snapshot
        let telemetry = snapshot.telemetry
        if family == .systemMedium {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    bars(snapshot: snapshot, telemetry: telemetry)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                WeatherCard(weather: snapshot.weather, snapshot: snapshot)
                    .frame(width: 120)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                bars(snapshot: snapshot, telemetry: telemetry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func bars(snapshot: DMSWidgetSnapshot, telemetry: DMSWidgetTelemetry) -> some View {
        Group {
            PillBar(label: "CPU",
                    value: "\(Int(telemetry.cpuPercent))%",
                    fraction: telemetry.cpuPercent / 100.0,
                    snapshot: snapshot)
            PillBar(label: "RAM",
                    value: String(format: "%.1f/%.0f GB", telemetry.ramUsedGB, telemetry.ramTotalGB),
                    fraction: telemetry.ramTotalGB > 0 ? telemetry.ramUsedGB / telemetry.ramTotalGB : 0,
                    snapshot: snapshot)
            if telemetry.hasBattery {
                PillBar(label: "Battery",
                        value: "\(telemetry.batteryPercent)%",
                        fraction: Double(telemetry.batteryPercent) / 100.0,
                        charging: telemetry.isCharging,
                        snapshot: snapshot)
            }
        }
    }
}

// MARK: - Pomodoro Focus

struct DMSPomodoroWidget: Widget {
    let kind: String = "DMSPomodoroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DMSWidgetProvider()) { entry in
            DMSPomodoroWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(dmsHex: entry.snapshot.palette.surfaceContainerHigh)
                }
        }
        .configurationDisplayName("Pomodoro Focus")
        .description("Live Pomodoro focus and break countdown synced with DankMacShell.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct DMSPomodoroWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DMSWidgetEntry

    var body: some View {
        let snapshot = entry.snapshot
        let pomodoro = snapshot.pomodoro
        let palette = snapshot.palette
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(pomodoro.phaseLabel)
                    .font(widgetFont(size: 12, weight: .bold, snapshot: snapshot))
                    .foregroundStyle(Color(dmsHex: palette.onPrimary))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(dmsHex: palette.primary)))
                Spacer()
                Text("Sessions: \(pomodoro.completedSessions)")
                    .font(widgetFont(size: 11, weight: .medium, snapshot: snapshot))
                    .foregroundStyle(Color(dmsHex: palette.onSurfaceVariant))
            }
            if pomodoro.isRunning, let end = pomodoro.endDate, end > entry.date {
                Text(timerInterval: entry.date...end, countsDown: true)
                    .font(widgetFont(size: family == .systemMedium ? 44 : 34, weight: .bold, mono: true, snapshot: snapshot))
                    .monospacedDigit()
                    .foregroundStyle(Color(dmsHex: palette.onSurface))
            } else if pomodoro.remainingSeconds > 0 {
                Text(mmss(pomodoro.remainingSeconds))
                    .font(widgetFont(size: family == .systemMedium ? 44 : 34, weight: .bold, mono: true, snapshot: snapshot))
                    .monospacedDigit()
                    .foregroundStyle(Color(dmsHex: palette.onSurface))
            } else {
                Text("Ready")
                    .font(widgetFont(size: family == .systemMedium ? 30 : 24, weight: .bold, snapshot: snapshot))
                    .foregroundStyle(Color(dmsHex: palette.onSurfaceVariant))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Widget Bundle

@main
struct DMSWidgetBundle: WidgetBundle {
    var body: some Widget {
        DMSClockWidget()
        DMSSystemWidget()
        DMSPomodoroWidget()
    }
}
