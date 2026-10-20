import Foundation

/// Primary navigation tabs available in DankDash.
public enum DashTab: String, CaseIterable, Codable, Sendable, Identifiable {
    case overview = "overview"
    case media = "media"
    case wallpapers = "wallpapers"
    case weather = "weather"
    case settings = "settings"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview: return "Overview"
        case .media: return "Media"
        case .wallpapers: return "Wallpapers"
        case .weather: return "Weather"
        case .settings: return "Settings"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .media: return "music.note"
        case .wallpapers: return "photo.artframe"
        case .weather: return "sun.max"
        case .settings: return "gearshape"
        }
    }

    public init?(fromString string: String) {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch clean {
        case "overview", "dash", "dankdash", "home":
            self = .overview
        case "media", "mpris", "music", "player":
            self = .media
        case "wallpapers", "wallpaper", "bg", "background":
            self = .wallpapers
        case "weather", "forecast", "meteo":
            self = .weather
        case "settings", "config", "preferences", "prefs":
            self = .settings
        default:
            return nil
        }
    }
}

/// Represents a year and month combination with navigation helpers.
public struct CalendarMonth: Sendable, Equatable, Hashable {
    public var year: Int
    public var month: Int // 1...12

    public init(year: Int, month: Int) {
        self.year = year
        self.month = max(1, min(12, month))
    }

    public init(date: Date = Date(), calendar: Calendar = Calendar.current) {
        self.year = calendar.component(.year, from: date)
        self.month = calendar.component(.month, from: date)
    }

    public var title: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        let monthName = fmt.monthSymbols[month - 1]
        return "\(monthName) \(year)"
    }

    public func nextMonth() -> CalendarMonth {
        if month == 12 {
            return CalendarMonth(year: year + 1, month: 1)
        } else {
            return CalendarMonth(year: year, month: month + 1)
        }
    }

    public func previousMonth() -> CalendarMonth {
        if month == 1 {
            return CalendarMonth(year: year - 1, month: 12)
        } else {
            return CalendarMonth(year: year, month: month - 1)
        }
    }
}

/// A day cell model in the 7-column calendar matrix.
public struct CalendarDayItem: Sendable, Equatable, Identifiable {
    public var id: String { "\(date.timeIntervalSince1970)_\(dayNumber)_\(isCurrentMonth)" }
    public var date: Date
    public var dayNumber: Int
    public var isCurrentMonth: Bool
    public var isToday: Bool
    public var isSelected: Bool
    public var hasEvents: Bool
    public var eventColorHex: String?

    public init(
        date: Date,
        dayNumber: Int,
        isCurrentMonth: Bool,
        isToday: Bool = false,
        isSelected: Bool = false,
        hasEvents: Bool = false,
        eventColorHex: String? = nil
    ) {
        self.date = date
        self.dayNumber = dayNumber
        self.isCurrentMonth = isCurrentMonth
        self.isToday = isToday
        self.isSelected = isSelected
        self.hasEvents = hasEvents
        self.eventColorHex = eventColorHex
    }
}

/// Computes the 7-column calendar grid for any year and month.
public struct CalendarEngine: Sendable {
    public static func dateKey(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func dateKey(from date: Date, calendar: Calendar = Calendar.current) -> String {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return dateKey(year: y, month: m, day: d)
    }

    /// Generates full month grid (42 days = 6 full 7-day rows)
    public static func generateMonthGrid(
        year: Int,
        month: Int,
        firstDayOfWeek: Int = 0, // 0 = Sunday, 1 = Monday
        selectedDate: Date? = nil,
        eventsDates: Set<Int>? = nil, // Day numbers with events in current month
        eventDateKeys: Set<String>? = nil // Full date keys "YYYY-MM-DD" across current and adjacent months
    ) -> [CalendarDayItem] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current

        var comp = DateComponents()
        comp.year = year
        comp.month = month
        comp.day = 1
        comp.hour = 12
        guard let firstDayOfMonth = cal.date(from: comp),
              let range = cal.range(of: .day, in: .month, for: firstDayOfMonth) else {
            return []
        }

        let weekday = cal.component(.weekday, from: firstDayOfMonth) // 1 = Sunday, 2 = Monday, ... 7 = Saturday
        var leadOffset = (weekday - 1 - firstDayOfWeek)
        if leadOffset < 0 { leadOffset += 7 }

        let prevMonth = month == 1 ? 12 : month - 1
        let prevYear = month == 1 ? year - 1 : year
        var prevComp = DateComponents()
        prevComp.year = prevYear
        prevComp.month = prevMonth
        prevComp.day = 1
        let prevFirst = cal.date(from: prevComp)!
        let prevRange = cal.range(of: .day, in: .month, for: prevFirst)!
        let prevDaysCount = prevRange.count

        let today = Date()
        let todayDay = cal.component(.day, from: today)
        let todayMonth = cal.component(.month, from: today)
        let todayYear = cal.component(.year, from: today)

        var items: [CalendarDayItem] = []

        // Previous month trailing days
        if leadOffset > 0 {
            for i in (prevDaysCount - leadOffset + 1)...prevDaysCount {
                var dComp = DateComponents()
                dComp.year = prevYear
                dComp.month = prevMonth
                dComp.day = i
                dComp.hour = 12
                let date = cal.date(from: dComp)!
                let key = dateKey(year: prevYear, month: prevMonth, day: i)
                let hasEv = eventDateKeys?.contains(key) ?? false
                items.append(CalendarDayItem(
                    date: date,
                    dayNumber: i,
                    isCurrentMonth: false,
                    isToday: false,
                    hasEvents: hasEv
                ))
            }
        }

        // Current month days
        for d in 1...range.count {
            var dComp = DateComponents()
            dComp.year = year
            dComp.month = month
            dComp.day = d
            dComp.hour = 12
            let date = cal.date(from: dComp)!
            let isTod = (d == todayDay && month == todayMonth && year == todayYear)
            let isSel: Bool
            if let selected = selectedDate {
                let selDay = cal.component(.day, from: selected)
                let selMonth = cal.component(.month, from: selected)
                let selYear = cal.component(.year, from: selected)
                isSel = (d == selDay && month == selMonth && year == selYear)
            } else {
                isSel = isTod
            }
            let key = dateKey(year: year, month: month, day: d)
            let hasEv: Bool
            if let keys = eventDateKeys {
                hasEv = keys.contains(key)
            } else if let dSet = eventsDates {
                hasEv = dSet.contains(d)
            } else {
                hasEv = false
            }
            items.append(CalendarDayItem(
                date: date,
                dayNumber: d,
                isCurrentMonth: true,
                isToday: isTod,
                isSelected: isSel,
                hasEvents: hasEv
            ))
        }

        // Next month leading days to complete 6 rows (42 items)
        let totalCellsNeeded = 42
        var nextDay = 1
        let nextMonth = month == 12 ? 1 : month + 1
        let nextYear = month == 12 ? year + 1 : year
        while items.count < totalCellsNeeded {
            var dComp = DateComponents()
            dComp.year = nextYear
            dComp.month = nextMonth
            dComp.day = nextDay
            dComp.hour = 12
            let date = cal.date(from: dComp)!
            let key = dateKey(year: nextYear, month: nextMonth, day: nextDay)
            let hasEv = eventDateKeys?.contains(key) ?? false
            items.append(CalendarDayItem(
                date: date,
                dayNumber: nextDay,
                isCurrentMonth: false,
                isToday: false,
                hasEvents: hasEv
            ))
            nextDay += 1
        }

        return items
    }
}

/// Formats uptime in seconds to human-readable strings like "up 16 hours, 22 minutes".
public struct UptimeFormatter: Sendable {
    public static func format(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60

        if days > 0 {
            let dStr = days == 1 ? "1 day" : "\(days) days"
            let hStr = hours == 1 ? "1 hour" : "\(hours) hours"
            return "up \(dStr), \(hStr)"
        } else if hours > 0 {
            let hStr = hours == 1 ? "1 hour" : "\(hours) hours"
            let mStr = minutes == 1 ? "1 minute" : "\(minutes) minutes"
            return "up \(hStr), \(mStr)"
        } else {
            let mStr = minutes == 1 ? "1 minute" : "\(minutes) minutes"
            return "up \(mStr)"
        }
    }
}

/// 8 astronomical moon phases.
public enum MoonPhase: String, CaseIterable, Sendable {
    case newMoon = "New Moon"
    case waxingCrescent = "Waxing Crescent"
    case firstQuarter = "First Quarter"
    case waxingGibbous = "Waxing Gibbous"
    case fullMoon = "Full Moon"
    case waningGibbous = "Waning Gibbous"
    case lastQuarter = "Last Quarter"
    case waningCrescent = "Waning Crescent"

    public var name: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .newMoon: return "moonphase.new.moon"
        case .waxingCrescent: return "moonphase.waxing.crescent"
        case .firstQuarter: return "moonphase.first.quarter"
        case .waxingGibbous: return "moonphase.waxing.gibbous"
        case .fullMoon: return "moonphase.full.moon"
        case .waningGibbous: return "moonphase.waning.gibbous"
        case .lastQuarter: return "moonphase.last.quarter"
        case .waningCrescent: return "moonphase.waning.crescent"
        }
    }
}

/// Celestial calculations for solar arc, day progress, and lunar phases.
public struct CelestialEngine: Sendable {
    public static func dayProgress(now: Date, sunrise: Date, sunset: Date) -> Double {
        let tNow = now.timeIntervalSince1970
        let tRise = sunrise.timeIntervalSince1970
        let tSet = sunset.timeIntervalSince1970
        guard tSet > tRise else { return 0.5 }
        let progress = (tNow - tRise) / (tSet - tRise)
        return min(1.0, max(0.0, progress))
    }

    public static func isDay(now: Date, sunrise: Date, sunset: Date) -> Bool {
        now >= sunrise && now <= sunset
    }

    /// Parabolic arc: 4 * p * (1 - p). At p=0: 0, p=0.5: 1, p=1: 0.
    public static func parabolicHeight(progress: Double) -> Double {
        let p = min(1.0, max(0.0, progress))
        return 4.0 * p * (1.0 - p)
    }

    /// Calculates moon phase based on approximate synodic cycle (29.530588 days)
    public static func moonPhase(date: Date) -> MoonPhase {
        let knownNewMoon = 1704974220.0
        let synodicPeriod = 29.530588 * 86400.0
        let elapsed = date.timeIntervalSince1970 - knownNewMoon
        let cycle = elapsed.truncatingRemainder(dividingBy: synodicPeriod)
        let normalized = (cycle < 0 ? cycle + synodicPeriod : cycle) / synodicPeriod

        if normalized < 0.0625 || normalized >= 0.9375 {
            return .newMoon
        } else if normalized < 0.1875 {
            return .waxingCrescent
        } else if normalized < 0.3125 {
            return .firstQuarter
        } else if normalized < 0.4375 {
            return .waxingGibbous
        } else if normalized < 0.5625 {
            return .fullMoon
        } else if normalized < 0.6875 {
            return .waningGibbous
        } else if normalized < 0.8125 {
            return .lastQuarter
        } else {
            return .waningCrescent
        }
    }
}

public struct WavePoint: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Generates points for Material 3 squiggly waveform scrub bar.
public struct SquigglyWaveformGenerator: Sendable {
    public static func generatePoints(
        width: Double,
        height: Double,
        progress: Double,
        waveLength: Double = 20.0,
        amplitude: Double = 4.0,
        phase: Double = 0.0
    ) -> [WavePoint] {
        guard width > 0 else { return [] }
        let clampedProgress = min(1.0, max(0.0, progress))
        let squigglyWidth = width * clampedProgress
        let midY = height / 2.0
        var points: [WavePoint] = []

        let step = 2.0
        var x = 0.0
        while x <= squigglyWidth {
            let angle = (x / max(1.0, waveLength)) * 2.0 * Double.pi + phase
            let y = midY + sin(angle) * amplitude
            points.append(WavePoint(x: x, y: y))
            x += step
        }

        // Remaining straight line
        if squigglyWidth < width {
            points.append(WavePoint(x: squigglyWidth, y: midY))
            points.append(WavePoint(x: width, y: midY))
        }

        return points
    }
}

