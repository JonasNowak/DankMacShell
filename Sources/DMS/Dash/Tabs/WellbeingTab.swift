import SwiftUI
import AppKit
import DMSCore

/// Dedicated Digital Wellbeing & App Focus Tracker dashboard tab in DankDash.
public struct WellbeingTab: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var wellbeingService = WellbeingService.shared

    @State private var selectedDateKey: String = WellbeingFormatter.dateKey(for: Date())
    @State private var editingAppLimit: (bundleID: String, appName: String)?
    @State private var limitMinutesInput: Double = 60

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let todayKey = WellbeingFormatter.dateKey(for: Date())
        let weeklySummaries = wellbeingService.store.weeklyTotals(currentDate: Date(), days: 7)
        let activeKey = selectedDateKey.isEmpty ? todayKey : selectedDateKey
        let dayTotal = wellbeingService.store.totalDuration(for: activeKey)
        let apps = wellbeingService.store.topApps(for: activeKey, limit: 10)

        VStack(spacing: 12) {
            // Screen Time Sync / Tracking Warning Banner
            if !wellbeingService.isTrackingActive {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text(wellbeingService.isMacOSScreenTimeActive ? "Focus tracking is disabled in DMS Settings." : "Focus tracking paused: macOS Screen Time is turned off or inactive.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                        .lineLimit(1)
                    Spacer()
                    Button("Open Screen Time") {
                        wellbeingService.openMacOSScreenTimeSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(10)
            }

            // Header Hero & Weekly Bar Chart
            HStack(spacing: 10) {
                // Total Screen Time Hero
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "hourglass")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: p.primary.hex))
                        Text(activeKey == todayKey ? "Today's Focus" : "Screen Time")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    }

                    Text(WellbeingFormatter.formatDuration(seconds: dayTotal))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: p.onSurface.hex))

                    Text("Active: \(wellbeingService.currentFrontmostApp)")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: p.outline.hex))
                        .lineLimit(1)
                }
                .padding(12)
                .frame(width: 160)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background(Color(hex: p.surfaceContainerHigh.hex))
                .cornerRadius(16)

                // 7-Day Weekly Bar Chart
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last 7 Days")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurface.hex))

                    let maxDailySecs = max(3600.0, weeklySummaries.map(\.totalSeconds).max() ?? 3600.0)

                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(weeklySummaries) { day in
                            let isSelected = (day.dateKey == activeKey)
                            let ratio = CGFloat(day.totalSeconds / maxDailySecs)

                            Button(action: {
                                selectedDateKey = day.dateKey
                            }) {
                                VStack(spacing: 4) {
                                    GeometryReader { barGeo in
                                        VStack {
                                            Spacer()
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(isSelected ? Color(hex: p.primary.hex) : (day.isToday ? Color(hex: p.primary.hex).opacity(0.6) : Color(hex: p.surfaceContainerHighest.hex)))
                                                .frame(height: max(4.0, barGeo.size.height * ratio))
                                        }
                                    }

                                    Text(day.dayLabel)
                                        .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(isSelected ? Color(hex: p.primary.hex) : Color(hex: p.outline.hex))
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: p.surfaceContainerHigh.hex))
                .cornerRadius(16)
            }
            .frame(height: 96)

            // App Breakdown List
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Top Applications")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                    Spacer()
                    Button(action: {
                        wellbeingService.openMacOSScreenTimeSettings()
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(wellbeingService.isMacOSScreenTimeActive ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            Text("macOS Screen Time")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(Color(hex: p.outline.hex))
                    }
                    .buttonStyle(.plain)
                    .help("Open macOS Screen Time in System Settings")
                }

                if apps.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "app.badge.checkmark")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: p.outline.hex))
                        Text("No application focus recorded for this day.")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(apps) { app in
                                AppUsageRow(
                                    app: app,
                                    dayTotalSeconds: dayTotal,
                                    limit: wellbeingService.store.limits[app.bundleID],
                                    palette: p,
                                    onEditLimit: {
                                        editingAppLimit = (bundleID: app.bundleID, appName: app.appName)
                                        limitMinutesInput = Double(wellbeingService.store.limits[app.bundleID]?.dailyLimitMinutes ?? 60)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(12)
            .background(Color(hex: p.surfaceContainerHigh.hex))
            .cornerRadius(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: Binding(
            get: { editingAppLimit.map { LimitEditTarget(bundleID: $0.bundleID, appName: $0.appName) } },
            set: { if $0 == nil { editingAppLimit = nil } }
        )) { target in
            LimitEditSheet(
                appName: target.appName,
                bundleID: target.bundleID,
                initialMinutes: Int(limitMinutesInput),
                palette: p,
                onSave: { mins in
                    wellbeingService.setDailyLimit(bundleID: target.bundleID, appName: target.appName, minutes: mins)
                    editingAppLimit = nil
                },
                onRemove: {
                    wellbeingService.removeDailyLimit(bundleID: target.bundleID)
                    editingAppLimit = nil
                },
                onCancel: {
                    editingAppLimit = nil
                }
            )
        }
    }
}

private struct LimitEditTarget: Identifiable {
    var id: String { bundleID }
    let bundleID: String
    let appName: String
}

private struct AppUsageRow: View {
    let app: AppUsageRecord
    let dayTotalSeconds: TimeInterval
    let limit: AppLimitConfig?
    let palette: DMSPalette
    let onEditLimit: () -> Void

    var body: some View {
        let percent = dayTotalSeconds > 0 ? Int(round((app.durationSeconds / dayTotalSeconds) * 100)) : 0
        let isExceeded = (limit != nil && limit!.enabled && app.durationSeconds >= limit!.dailyLimitSeconds)

        HStack(spacing: 8) {
            // App Icon
            if let icon = resolveAppIcon(bundleID: app.bundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: palette.primary.hex))
                    .frame(width: 22, height: 22)
            }

            // App Name & Percentage
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(app.appName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                        .lineLimit(1)

                    if isExceeded {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: palette.error.hex))
                    }
                }

                Text("\(percent)% of screen time")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: palette.outline.hex))
            }

            Spacer()

            // Usage Bar
            GeometryReader { geo in
                let ratio = dayTotalSeconds > 0 ? (app.durationSeconds / dayTotalSeconds) : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: palette.surfaceContainerHighest.hex))
                    Capsule()
                        .fill(isExceeded ? Color(hex: palette.error.hex) : Color(hex: palette.primary.hex))
                        .frame(width: geo.size.width * CGFloat(ratio))
                }
            }
            .frame(width: 60, height: 5)

            // Duration
            Text(WellbeingFormatter.formatDuration(seconds: app.durationSeconds))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: palette.onSurface.hex))
                .frame(width: 44, alignment: .trailing)

            // Limit Config Button
            Button(action: onEditLimit) {
                Image(systemName: limit != nil ? "hourglass.circle.fill" : "hourglass.badge.plus")
                    .font(.system(size: 13))
                    .foregroundColor(limit != nil ? (isExceeded ? Color(hex: palette.error.hex) : Color(hex: palette.primary.hex)) : Color(hex: palette.outline.hex))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: palette.surfaceContainerLow.hex).opacity(0.6))
        .cornerRadius(10)
    }

    private func resolveAppIcon(bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

private struct LimitEditSheet: View {
    let appName: String
    let bundleID: String
    @State var minutes: Double
    let palette: DMSPalette
    let onSave: (Int) -> Void
    let onRemove: () -> Void
    let onCancel: () -> Void

    init(
        appName: String,
        bundleID: String,
        initialMinutes: Int,
        palette: DMSPalette,
        onSave: @escaping (Int) -> Void,
        onRemove: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.appName = appName
        self.bundleID = bundleID
        self._minutes = State(initialValue: Double(initialMinutes))
        self.palette = palette
        self.onSave = onSave
        self.onRemove = onRemove
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Set Daily Limit for \(appName)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: palette.onSurface.hex))

            VStack(spacing: 6) {
                Text("\(Int(minutes)) minutes per day")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: palette.primary.hex))

                Slider(value: $minutes, in: 5...360, step: 5)
                    .tint(Color(hex: palette.primary.hex))
            }
            .padding(.horizontal, 10)

            HStack(spacing: 8) {
                Button("Remove Limit", action: onRemove)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: palette.error.hex))

                Spacer()

                Button("Cancel", action: onCancel)
                    .font(.system(size: 11))

                Button("Save") {
                    onSave(Int(minutes))
                }
                .font(.system(size: 11, weight: .bold))
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color(hex: palette.surfaceContainerHigh.hex))
    }
}
