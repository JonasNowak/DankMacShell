import Testing
import Foundation
@testable import DMSCore

@Suite("Dash and Overview Specification Tests")
struct DashTests {

    // MARK: - DASH-TAB: Tab Enum and Parsing
    @Test("DashTab Enumeration, Labels, and Symbols")
    func testDashTabProperties() {
        #expect(DashTab.allCases.count == 5)
        
        #expect(DashTab.overview.rawValue == "overview")
        #expect(DashTab.overview.title == "Overview")
        #expect(DashTab.overview.sfSymbol == "square.grid.2x2")
        
        #expect(DashTab.media.rawValue == "media")
        #expect(DashTab.media.title == "Media")
        #expect(DashTab.media.sfSymbol == "music.note")
        
        #expect(DashTab.wallpapers.rawValue == "wallpapers")
        #expect(DashTab.wallpapers.title == "Wallpapers")
        #expect(DashTab.wallpapers.sfSymbol == "photo.artframe")
        
        #expect(DashTab.weather.rawValue == "weather")
        #expect(DashTab.weather.title == "Weather")
        #expect(DashTab.weather.sfSymbol == "sun.max")
        
        #expect(DashTab.settings.rawValue == "settings")
        #expect(DashTab.settings.title == "Settings")
        #expect(DashTab.settings.sfSymbol == "gearshape")
    }

    @Test("DashTab Case-Insensitive Parsing and Aliases")
    func testDashTabParsing() {
        #expect(DashTab(fromString: "overview") == .overview)
        #expect(DashTab(fromString: "OVERVIEW") == .overview)
        #expect(DashTab(fromString: "dash") == .overview)
        
        #expect(DashTab(fromString: "media") == .media)
        #expect(DashTab(fromString: "mpris") == .media)
        #expect(DashTab(fromString: "music") == .media)
        
        #expect(DashTab(fromString: "wallpapers") == .wallpapers)
        #expect(DashTab(fromString: "wallpaper") == .wallpapers)
        
        #expect(DashTab(fromString: "weather") == .weather)
        #expect(DashTab(fromString: "forecast") == .weather)
        
        #expect(DashTab(fromString: "settings") == .settings)
        #expect(DashTab(fromString: "config") == .settings)
        #expect(DashTab(fromString: "preferences") == .settings)
        
        #expect(DashTab(fromString: "nonexistent") == nil)
    }

    // MARK: - DASH-CAL: Calendar Grid Engine
    @Test("Calendar Engine October 2025 Sunday-First Grid Matches Spec")
    func testOctober2025GridSundayFirst() {
        // October 2025 has 31 days.
        // October 1, 2025 is a Wednesday.
        // With firstDayOfWeek = 0 (Sunday):
        // Row 1 starts on Sunday Sep 28: 28, 29, 30, 1, 2, 3, 4
        let days = CalendarEngine.generateMonthGrid(year: 2025, month: 10, firstDayOfWeek: 0)
        
        // Grid should have 42 cells (6 full weeks of 7 days)
        #expect(days.count == 42)
        
        // First 3 cells are from September (previous month)
        #expect(days[0].dayNumber == 28)
        #expect(days[0].isCurrentMonth == false)
        #expect(days[1].dayNumber == 29)
        #expect(days[1].isCurrentMonth == false)
        #expect(days[2].dayNumber == 30)
        #expect(days[2].isCurrentMonth == false)
        
        // Day 1 of October is at index 3 (Wednesday)
        #expect(days[3].dayNumber == 1)
        #expect(days[3].isCurrentMonth == true)
        
        // October 28 (shown highlighted in screenshot) is at index 30 (Tuesday)
        let day28 = days.first(where: { $0.dayNumber == 28 && $0.isCurrentMonth })
        #expect(day28 != nil)
        
        // Day 31 of October is Friday at index 33
        #expect(days[33].dayNumber == 31)
        #expect(days[33].isCurrentMonth == true)
        
        // Trailing days are from November (Nov 1 to Nov 8)
        #expect(days[34].dayNumber == 1)
        #expect(days[34].isCurrentMonth == false)
        #expect(days[41].dayNumber == 8)
        #expect(days[41].isCurrentMonth == false)
    }

    @Test("Calendar Engine Monday-First Week Offset")
    func testOctober2025GridMondayFirst() {
        // October 1, 2025 is a Wednesday.
        // With firstDayOfWeek = 1 (Monday):
        // Monday = Sep 29, Tuesday = Sep 30, Wednesday = Oct 1
        let days = CalendarEngine.generateMonthGrid(year: 2025, month: 10, firstDayOfWeek: 1)
        
        #expect(days[0].dayNumber == 29)
        #expect(days[0].isCurrentMonth == false)
        #expect(days[1].dayNumber == 30)
        #expect(days[1].isCurrentMonth == false)
        #expect(days[2].dayNumber == 1)
        #expect(days[2].isCurrentMonth == true)
    }

    @Test("Calendar Engine Multi-Month Event Keys Match Reference Design")
    func testOctober2025GridWithMultiMonthEventKeys() {
        // In dankdash.png:
        // October 2025 has events on:
        // - Oct 12, 13, 14, 22, 25, 26, 28, 31
        // - Nov 2, 4 (next month leading days)
        // Crucially, Oct 2 and Oct 4 do NOT have events!
        let refKeys: Set<String> = [
            "2025-10-12", "2025-10-13", "2025-10-14", "2025-10-22",
            "2025-10-25", "2025-10-26", "2025-10-28", "2025-10-31",
            "2025-11-02", "2025-11-04"
        ]

        let days = CalendarEngine.generateMonthGrid(
            year: 2025,
            month: 10,
            firstDayOfWeek: 0,
            eventDateKeys: refKeys
        )

        #expect(days.count == 42)

        // Check October days that SHOULD have events
        let oct12 = days.first(where: { $0.isCurrentMonth && $0.dayNumber == 12 })
        #expect(oct12?.hasEvents == true)

        let oct13 = days.first(where: { $0.isCurrentMonth && $0.dayNumber == 13 })
        #expect(oct13?.hasEvents == true)

        let oct14 = days.first(where: { $0.isCurrentMonth && $0.dayNumber == 14 })
        #expect(oct14?.hasEvents == true)

        let oct22 = days.first(where: { $0.isCurrentMonth && $0.dayNumber == 22 })
        #expect(oct22?.hasEvents == true)

        let oct25 = days.first(where: { $0.isCurrentMonth && $0.dayNumber == 25 })
        #expect(oct25?.hasEvents == true)

        let oct26 = days.first(where: { $0.isCurrentMonth && $0.dayNumber == 26 })
        #expect(oct26?.hasEvents == true)

        let oct28 = days.first(where: { $0.isCurrentMonth && $0.dayNumber == 28 })
        #expect(oct28?.hasEvents == true)

        let oct31 = days.first(where: { $0.isCurrentMonth && $0.dayNumber == 31 })
        #expect(oct31?.hasEvents == true)

        // Crucial test against the prior bug: Oct 2 and Oct 4 must NOT have events!
        let oct2 = days.first(where: { $0.isCurrentMonth && $0.dayNumber == 2 })
        #expect(oct2?.hasEvents == false)

        let oct4 = days.first(where: { $0.isCurrentMonth && $0.dayNumber == 4 })
        #expect(oct4?.hasEvents == false)

        // Next month November 2 and November 4 MUST have events (fixing prior attempt hardcoded false)
        let nov2 = days.first(where: { !$0.isCurrentMonth && $0.dayNumber == 2 })
        #expect(nov2 != nil)
        #expect(nov2?.hasEvents == true)

        let nov4 = days.first(where: { !$0.isCurrentMonth && $0.dayNumber == 4 })
        #expect(nov4 != nil)
        #expect(nov4?.hasEvents == true)

        // Other next month days must not have events
        let nov3 = days.first(where: { !$0.isCurrentMonth && $0.dayNumber == 3 })
        #expect(nov3?.hasEvents == false)
    }

    @Test("Calendar Engine DateKey Formatting Helpers")
    func testCalendarEngineDateKeyHelper() {
        #expect(CalendarEngine.dateKey(year: 2025, month: 10, day: 28) == "2025-10-28")
        #expect(CalendarEngine.dateKey(year: 2025, month: 2, day: 5) == "2025-02-05")

        let cal = Calendar(identifier: .gregorian)
        var comp = DateComponents()
        comp.year = 2025
        comp.month = 11
        comp.day = 2
        comp.hour = 12
        let date = cal.date(from: comp)!
        #expect(CalendarEngine.dateKey(from: date, calendar: cal) == "2025-11-02")
    }

    @Test("Calendar Month Navigation and Year Rollover")
    func testCalendarMonthNavigation() {
        let oct2025 = CalendarMonth(year: 2025, month: 10)
        #expect(oct2025.title == "October 2025")
        
        let nov2025 = oct2025.nextMonth()
        #expect(nov2025.year == 2025)
        #expect(nov2025.month == 11)
        #expect(nov2025.title == "November 2025")
        
        let dec2025 = nov2025.nextMonth()
        let jan2026 = dec2025.nextMonth()
        #expect(jan2026.year == 2026)
        #expect(jan2026.month == 1)
        
        let backDec2025 = jan2026.previousMonth()
        #expect(backDec2025.year == 2025)
        #expect(backDec2025.month == 12)
    }

    // MARK: - DASH-UPTIME: Formatted System Uptime
    @Test("Uptime Formatter Output Formats")
    func testUptimeFormatting() {
        // Exactly matching the screenshot: "up 16 hours, 22 minutes"
        let seconds = (16 * 3600) + (22 * 60) + 15
        #expect(UptimeFormatter.format(seconds: TimeInterval(seconds)) == "up 16 hours, 22 minutes")
        
        // Multi-day uptime
        let multiDay = (2 * 86400) + (4 * 3600) + (10 * 60)
        #expect(UptimeFormatter.format(seconds: TimeInterval(multiDay)) == "up 2 days, 4 hours")
        
        // Single day singular
        let oneDay = 86400 + (1 * 3600)
        #expect(UptimeFormatter.format(seconds: TimeInterval(oneDay)) == "up 1 day, 1 hour")
        
        // Minutes only (< 1 hour)
        let minutesOnly = (45 * 60) + 30
        #expect(UptimeFormatter.format(seconds: TimeInterval(minutesOnly)) == "up 45 minutes")
        
        // Zero or negative
        #expect(UptimeFormatter.format(seconds: 0) == "up 0 minutes")
        #expect(UptimeFormatter.format(seconds: -10) == "up 0 minutes")
    }

    // MARK: - DASH-WEATH: Celestial Arc Calculations
    @Test("Celestial Engine Day Progress and Parabola")
    func testCelestialEngineCalculations() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 28
        components.hour = 6
        components.minute = 0
        let sunrise = calendar.date(from: components)!
        
        components.hour = 18
        let sunset = calendar.date(from: components)!
        
        // Midday (12:00) -> progress exactly 0.5
        components.hour = 12
        let noon = calendar.date(from: components)!
        let progressNoon = CelestialEngine.dayProgress(now: noon, sunrise: sunrise, sunset: sunset)
        #expect(abs(progressNoon - 0.5) < 0.001)
        
        // Parabola height at progress 0.5 is 1.0 (peak)
        let peakHeight = CelestialEngine.parabolicHeight(progress: progressNoon)
        #expect(abs(peakHeight - 1.0) < 0.001)
        
        // Parabola height at sunrise (0.0) and sunset (1.0) is 0.0
        #expect(abs(CelestialEngine.parabolicHeight(progress: 0.0)) < 0.001)
        #expect(abs(CelestialEngine.parabolicHeight(progress: 1.0)) < 0.001)
        
        // Clamping before sunrise and after sunset
        components.hour = 4
        let earlyMorning = calendar.date(from: components)!
        #expect(CelestialEngine.dayProgress(now: earlyMorning, sunrise: sunrise, sunset: sunset) == 0.0)
        #expect(CelestialEngine.isDay(now: earlyMorning, sunrise: sunrise, sunset: sunset) == false)
        
        components.hour = 22
        let lateNight = calendar.date(from: components)!
        #expect(CelestialEngine.dayProgress(now: lateNight, sunrise: sunrise, sunset: sunset) == 1.0)
        #expect(CelestialEngine.isDay(now: lateNight, sunrise: sunrise, sunset: sunset) == false)
    }

    @Test("Celestial Engine Moon Phase Symbols")
    func testMoonPhases() {
        let phases = MoonPhase.allCases
        #expect(phases.count == 8)
        for phase in phases {
            #expect(!phase.sfSymbol.isEmpty)
            #expect(!phase.name.isEmpty)
        }
    }

    // MARK: - DASH-IPC: IPC Command Parsing for Dash
    @Test("IPC URL and CLI Parsing for Dash Tabs")
    func testIPCDashCommands() {
        // URLs
        #expect(IPCCommand.parse(url: URL(string: "dms://dash")!) == .toggleDash)
        #expect(IPCCommand.parse(url: URL(string: "dms://dash/open")!) == .openDash)
        #expect(IPCCommand.parse(url: URL(string: "dms://dash/open?tab=weather")!) == .openDashTab(tab: "weather"))
        #expect(IPCCommand.parse(url: URL(string: "dms://dash/open?tab=media")!) == .openDashTab(tab: "media"))
        #expect(IPCCommand.parse(url: URL(string: "dms://dash/close")!) == .closeDash)
        
        // CLI args
        #expect(IPCCommand.parseCLI(args: ["dash", "open", "--tab", "weather"]) == .openDashTab(tab: "weather"))
        #expect(IPCCommand.parseCLI(args: ["dash", "open", "media"]) == .openDashTab(tab: "media"))
        #expect(IPCCommand.parseCLI(args: ["dash", "close"]) == .closeDash)
        #expect(IPCCommand.parseCLI(args: ["dash", "toggle"]) == .toggleDash)
    }

    // MARK: - DASH-MEDIA: Squiggly Waveform Math
    @Test("Squiggly Waveform Point Generation")
    func testSquigglyWaveformMath() {
        let points = SquigglyWaveformGenerator.generatePoints(
            width: 200,
            height: 20,
            progress: 0.6,
            waveLength: 20,
            amplitude: 4
        )
        
        #expect(!points.isEmpty)
        // First point starts at x=0
        #expect(points.first?.x == 0.0)
        // Last point reaches width
        #expect(points.last?.x == 200.0)
    }
}
