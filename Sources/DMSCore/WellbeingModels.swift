import Foundation

/// A single day's usage duration record for a specific application.
public struct AppUsageRecord: Sendable, Codable, Equatable, Identifiable {
    public var id: String { "\(dateKey)_\(bundleID)" }
    public var bundleID: String
    public var appName: String
    public var dateKey: String
    public var durationSeconds: TimeInterval

    public init(
        bundleID: String,
        appName: String,
        dateKey: String,
        durationSeconds: TimeInterval
    ) {
        self.bundleID = bundleID
        self.appName = appName
        self.dateKey = dateKey
        self.durationSeconds = max(0, durationSeconds)
    }
}

/// User-configured daily usage quota limit for an application.
public struct AppLimitConfig: Sendable, Codable, Equatable, Identifiable {
    public var id: String { bundleID }
    public var bundleID: String
    public var appName: String
    public var dailyLimitMinutes: Int
    public var enabled: Bool

    public var dailyLimitSeconds: TimeInterval {
        Double(dailyLimitMinutes) * 60.0
    }

    public init(
        bundleID: String,
        appName: String,
        dailyLimitMinutes: Int,
        enabled: Bool = true
    ) {
        self.bundleID = bundleID
        self.appName = appName
        self.dailyLimitMinutes = max(1, dailyLimitMinutes)
        self.enabled = enabled
    }
}

/// Summary item for 7-day weekly history charts.
public struct WeeklyDaySummary: Sendable, Equatable, Identifiable {
    public var id: String { dateKey }
    public var dateKey: String
    public var dayLabel: String
    public var totalSeconds: TimeInterval
    public var isToday: Bool

    public init(
        dateKey: String,
        dayLabel: String,
        totalSeconds: TimeInterval,
        isToday: Bool = false
    ) {
        self.dateKey = dateKey
        self.dayLabel = dayLabel
        self.totalSeconds = max(0, totalSeconds)
        self.isToday = isToday
    }
}

/// Persistent data store holding daily app usage records and quotas.
public struct WellbeingStoreData: Sendable, Codable, Equatable {
    /// Date key -> bundle ID -> AppUsageRecord
    public var records: [String: [String: AppUsageRecord]]
    /// Bundle ID -> AppLimitConfig
    public var limits: [String: AppLimitConfig]
    public var retentionDays: Int

    public init(
        records: [String: [String: AppUsageRecord]] = [:],
        limits: [String: AppLimitConfig] = [:],
        retentionDays: Int = 92
    ) {
        self.records = records
        self.limits = limits
        self.retentionDays = max(7, retentionDays)
    }

    /// Adds or accumulates active focus time for an application on a given date.
    public mutating func addUsage(
        bundleID: String,
        appName: String,
        dateKey: String,
        seconds: TimeInterval
    ) {
        guard seconds > 0 else { return }
        var dayMap = records[dateKey] ?? [:]
        if let existing = dayMap[bundleID] {
            dayMap[bundleID] = AppUsageRecord(
                bundleID: bundleID,
                appName: appName.isEmpty ? existing.appName : appName,
                dateKey: dateKey,
                durationSeconds: existing.durationSeconds + seconds
            )
        } else {
            dayMap[bundleID] = AppUsageRecord(
                bundleID: bundleID,
                appName: appName.isEmpty ? bundleID : appName,
                dateKey: dateKey,
                durationSeconds: seconds
            )
        }
        records[dateKey] = dayMap
    }

    /// Sets or updates a daily quota limit for an app.
    public mutating func setLimit(bundleID: String, appName: String, minutes: Int, enabled: Bool = true) {
        limits[bundleID] = AppLimitConfig(
            bundleID: bundleID,
            appName: appName,
            dailyLimitMinutes: minutes,
            enabled: enabled
        )
    }

    /// Removes a quota limit for an app.
    public mutating func removeLimit(bundleID: String) {
        limits.removeValue(forKey: bundleID)
    }

    /// Prunes usage records older than the retention threshold (default 92 days).
    public mutating func prune(currentDate: Date = Date(), retentionDays: Int = 92) {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: currentDate) else {
            return
        }
        let cutoffKey = WellbeingFormatter.dateKey(for: cutoffDate)
        records = records.filter { $0.key >= cutoffKey }
    }

    /// Total screen focus seconds across all applications for a given date.
    public func totalDuration(for dateKey: String) -> TimeInterval {
        guard let dayMap = records[dateKey] else { return 0 }
        return dayMap.values.reduce(0.0) { $0 + $1.durationSeconds }
    }

    /// Top focused apps for a given date sorted descending by duration.
    public func topApps(for dateKey: String, limit: Int = 5) -> [AppUsageRecord] {
        guard let dayMap = records[dateKey] else { return [] }
        let sorted = dayMap.values.sorted { $0.durationSeconds > $1.durationSeconds }
        return Array(sorted.prefix(max(1, limit)))
    }

    /// Aggregates last N days of usage for 7-day weekly charts.
    public func weeklyTotals(currentDate: Date = Date(), days: Int = 7) -> [WeeklyDaySummary] {
        let calendar = Calendar.current
        var summaries: [WeeklyDaySummary] = []
        let todayKey = WellbeingFormatter.dateKey(for: currentDate)

        for offset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: currentDate) else { continue }
            let key = WellbeingFormatter.dateKey(for: date)
            let label = WellbeingFormatter.dayLabel(for: date)
            let total = totalDuration(for: key)
            summaries.append(WeeklyDaySummary(
                dateKey: key,
                dayLabel: label,
                totalSeconds: total,
                isToday: (key == todayKey)
            ))
        }
        return summaries
    }

    /// Checks if an app has exceeded its daily quota on a specific date.
    public func isLimitExceeded(bundleID: String, dateKey: String) -> Bool {
        guard let limit = limits[bundleID], limit.enabled else { return false }
        guard let dayMap = records[dateKey], let record = dayMap[bundleID] else { return false }
        return record.durationSeconds >= limit.dailyLimitSeconds
    }
}

/// Helpers for formatting wellbeing durations and date keys.
public enum WellbeingFormatter: Sendable {
    private static let keyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE"
        return df
    }()

    public static func dateKey(for date: Date) -> String {
        keyFormatter.string(from: date)
    }

    public static func dayLabel(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    public static func formatDuration(seconds: TimeInterval) -> String {
        let sec = Int(max(0, seconds.rounded()))
        let hours = sec / 3600
        let minutes = (sec % 3600) / 60
        let remainder = sec % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(remainder)s"
        }
    }

    public static func formatDurationDetailed(seconds: TimeInterval) -> String {
        let sec = Int(max(0, seconds.rounded()))
        let hours = sec / 3600
        let minutes = (sec % 3600) / 60
        let remainder = sec % 60

        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(remainder) sec"
        }
    }
}
