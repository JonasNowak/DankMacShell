import Testing
import Foundation
@testable import DMSCore

@Suite("Digital Wellbeing Models and Retention Tests")
struct WellbeingTests {

    @Test("WellbeingStoreData Duration Accumulation")
    func testDurationAccumulation() {
        var store = WellbeingStoreData()
        let dateKey = "2026-11-02"

        store.addUsage(bundleID: "com.apple.Terminal", appName: "Terminal", dateKey: dateKey, seconds: 120)
        store.addUsage(bundleID: "com.apple.Terminal", appName: "Terminal", dateKey: dateKey, seconds: 60)
        store.addUsage(bundleID: "com.apple.Safari", appName: "Safari", dateKey: dateKey, seconds: 300)

        #expect(store.totalDuration(for: dateKey) == 480.0)

        let topApps = store.topApps(for: dateKey, limit: 5)
        #expect(topApps.count == 2)
        #expect(topApps[0].bundleID == "com.apple.Safari")
        #expect(topApps[0].durationSeconds == 300.0)
        #expect(topApps[1].bundleID == "com.apple.Terminal")
        #expect(topApps[1].durationSeconds == 180.0)
    }

    @Test("WellbeingStoreData 7-Day Weekly Aggregation")
    func testWeeklyAggregation() {
        var store = WellbeingStoreData()
        let calendar = Calendar.current
        let today = Date()

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = WellbeingFormatter.dateKey(for: date)
            store.addUsage(bundleID: "com.apple.Terminal", appName: "Terminal", dateKey: key, seconds: Double((offset + 1) * 100))
        }

        let weekly = store.weeklyTotals(currentDate: today, days: 7)
        #expect(weekly.count == 7)
        #expect(weekly.last?.isToday == true)
        #expect(weekly.last?.totalSeconds == 100.0)
    }

    @Test("WellbeingStoreData 92-Day Retention Pruning")
    func testRetentionPruning() {
        var store = WellbeingStoreData(retentionDays: 92)
        let calendar = Calendar.current
        let today = Date()

        // Recent record (10 days ago)
        let recentDate = calendar.date(byAdding: .day, value: -10, to: today)!
        let recentKey = WellbeingFormatter.dateKey(for: recentDate)
        store.addUsage(bundleID: "com.apple.Safari", appName: "Safari", dateKey: recentKey, seconds: 500)

        // Expired record (100 days ago)
        let expiredDate = calendar.date(byAdding: .day, value: -100, to: today)!
        let expiredKey = WellbeingFormatter.dateKey(for: expiredDate)
        store.addUsage(bundleID: "com.apple.Safari", appName: "Safari", dateKey: expiredKey, seconds: 500)

        #expect(store.records.count == 2)

        // Run pruning with retentionDays = 92
        store.prune(currentDate: today, retentionDays: 92)

        #expect(store.records.count == 1)
        #expect(store.records[recentKey] != nil)
        #expect(store.records[expiredKey] == nil)
    }

    @Test("Daily App Quota Limit Enforcement")
    func testAppQuotaLimit() {
        var store = WellbeingStoreData()
        let dateKey = "2026-11-02"
        let bid = "com.apple.Safari"

        // Set 30 minute daily limit
        store.setLimit(bundleID: bid, appName: "Safari", minutes: 30, enabled: true)

        // 20 minutes used -> not exceeded
        store.addUsage(bundleID: bid, appName: "Safari", dateKey: dateKey, seconds: 20 * 60)
        #expect(store.isLimitExceeded(bundleID: bid, dateKey: dateKey) == false)

        // Additional 15 minutes used (total 35m) -> exceeded
        store.addUsage(bundleID: bid, appName: "Safari", dateKey: dateKey, seconds: 15 * 60)
        #expect(store.isLimitExceeded(bundleID: bid, dateKey: dateKey) == true)
    }

    @Test("Wellbeing Formatter String Representations")
    func testWellbeingFormatter() {
        #expect(WellbeingFormatter.formatDuration(seconds: 45) == "45s")
        #expect(WellbeingFormatter.formatDuration(seconds: 125) == "2m")
        #expect(WellbeingFormatter.formatDuration(seconds: 3720) == "1h 2m")
        #expect(WellbeingFormatter.formatDurationDetailed(seconds: 3720) == "1 hr 2 min")
    }

    @Test("DMSConfig Digital Wellbeing Defaults and Serialization")
    func testConfigWellbeingSerialization() throws {
        var config = DMSConfig()
        #expect(config.enableWellbeing == true)
        #expect(config.syncWellbeingWithMacOS == true)

        config.enableWellbeing = false
        config.syncWellbeingWithMacOS = false

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DMSConfig.self, from: data)

        #expect(decoded.enableWellbeing == false)
        #expect(decoded.syncWellbeingWithMacOS == false)
    }

    @Test("DMSConfig Dynamic Setting Accessors for Wellbeing")
    func testConfigDynamicWellbeingSettings() {
        var config = DMSConfig()

        #expect(config.getSetting("enableWellbeing")?.boolValue == true)
        #expect(config.getSetting("syncWellbeingWithMacOS")?.boolValue == true)

        config.setSetting("enableWellbeing", value: AnyCodable(false))
        config.setSetting("syncWellbeingWithMacOS", value: AnyCodable(false))

        #expect(config.enableWellbeing == false)
        #expect(config.syncWellbeingWithMacOS == false)
        #expect(config.getSetting("wellbeingEnabled")?.boolValue == false)
        #expect(config.getSetting("syncWellbeingWithScreenTime")?.boolValue == false)
    }

    @Test("IPCCommand Wellbeing CLI and URL Parsing")
    func testIPCWellbeingCommands() {
        // CLI parsing
        let cmdStatus = IPCCommand.parseCLI(args: ["wellbeing", "status"])
        #expect(cmdStatus == .wellbeing(action: "status", arg: nil))

        let cmdSync = IPCCommand.parseCLI(args: ["screentime", "sync", "false"])
        #expect(cmdSync == .wellbeing(action: "sync", arg: "false"))

        let cmdOpen = IPCCommand.parseCLI(args: ["wellbeing", "open-system"])
        #expect(cmdOpen == .wellbeing(action: "open-system", arg: nil))

        // URL parsing
        let urlStatus = URL(string: "dms://wellbeing/status")!
        #expect(IPCCommand.parse(url: urlStatus) == .wellbeing(action: "status", arg: nil))

        let urlSync = URL(string: "dms://screentime?action=sync&value=true")!
        #expect(IPCCommand.parse(url: urlSync) == .wellbeing(action: "sync", arg: "true"))
    }
}
