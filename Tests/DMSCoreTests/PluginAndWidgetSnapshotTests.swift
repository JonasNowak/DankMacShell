import Testing
import Foundation
@testable import DMSCore

@Suite("Plugin Model and Widget Snapshot Tests")
struct PluginAndWidgetSnapshotTests {

    @Test("Widget snapshot write/read round-trip in a temp directory")
    func testWidgetSnapshotRoundTrip() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dms_widget_test_\(UUID().uuidString)", isDirectory: true)
        let url = dir.appendingPathComponent("widget-snapshot.json")
        defer { try? FileManager.default.removeItem(at: dir) }

        // Whole-second dates: the ISO8601 strategy drops fractional seconds.
        var snapshot = DMSWidgetSnapshot.placeholder
        snapshot.palette = DMSWidgetPalette(primary: "#FF0000", isDark: false)
        snapshot.fontFamily = "JetBrains Mono"
        snapshot.useSingleFontEverywhere = true
        snapshot.telemetry = DMSWidgetTelemetry(
            cpuPercent: 42.5,
            ramPercent: 61.25,
            ramUsedGB: 9.8,
            ramTotalGB: 16,
            batteryPercent: 87,
            isCharging: true,
            hasBattery: true
        )
        snapshot.weather = DMSWidgetWeather(temperatureText: "21°", condition: "Sunny", sfSymbol: "sun.max.fill", location: "Berlin")
        snapshot.pomodoro = DMSWidgetPomodoro(
            isRunning: true,
            isBreak: false,
            phaseLabel: "Focus",
            endDate: Date(timeIntervalSince1970: 1_700_000_600),
            remainingSeconds: 600,
            completedSessions: 2
        )
        snapshot.updatedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try DMSWidgetSnapshotStore.write(snapshot, to: url)
        #expect(FileManager.default.fileExists(atPath: url.path))

        let read = DMSWidgetSnapshotStore.read(from: url)
        #expect(read == snapshot)
        #expect(read?.pomodoro.endDate == Date(timeIntervalSince1970: 1_700_000_600))
    }

    @Test("Widget snapshot store returns nil for missing file and builds expected URLs")
    func testWidgetSnapshotStoreEdgeCases() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dms_missing_\(UUID().uuidString).json")
        #expect(DMSWidgetSnapshotStore.read(from: missing) == nil)

        let host = DMSWidgetSnapshotStore.hostSnapshotURL(homeDirectory: URL(fileURLWithPath: "/tmp/fakehome"))
        #expect(host.path == "/tmp/fakehome/Library/Containers/io.github.jonasnowak.dms.widgets/Data/Library/Application Support/DMS/widget-snapshot.json")

        let ext = DMSWidgetSnapshotStore.extensionSnapshotURL()
        #expect(ext.lastPathComponent == "widget-snapshot.json")
        #expect(ext.path.contains("Application Support/DMS"))
    }

    @Test("Standard plugins contains exactly the four real official built-ins")
    func testStandardPlugins() {
        let plugins = DMSPluginRegistry.standardPlugins
        #expect(plugins.count == 4)
        #expect(Set(plugins.map(\.id)) == ["pomodoro-timer", "tailscale-status", "github-notifications", "symbian-belle-sync"])
        let allOfficial = plugins.allSatisfy(\.isOfficial)
        #expect(allOfficial)

        for removed in ["network-speed", "crypto-tracker", "disk-usage", "spotify-mini", "currency-converter"] {
            #expect(plugins.first(where: { $0.id == removed }) == nil)
        }

        let pomodoro = plugins.first(where: { $0.id == "pomodoro-timer" })
        #expect(pomodoro?.name == "Pomodoro Focus Timer")
        #expect(pomodoro?.description == "Productivity timer with focus/break intervals, DankBar countdown pill, and native Desktop Widget.")
        #expect(pomodoro?.author == "DankMacShell")
        #expect(pomodoro?.version == "1.1.0")
        #expect(pomodoro?.type == .barWidget)
        #expect(pomodoro?.isInstalled == true)
        #expect(pomodoro?.isEnabled == false)
        #expect(pomodoro?.icon == "timer")
        #expect(pomodoro?.repoURL == "https://github.com/JonasNowak/DankMacShell")
        #expect(pomodoro?.tags == ["pomodoro", "timer", "focus", "productivity"])

        let tailscale = plugins.first(where: { $0.id == "tailscale-status" })
        #expect(tailscale?.name == "Tailscale VPN Pill")
        #expect(tailscale?.icon == "shield.checkered")
        #expect(tailscale?.tags == ["tailscale", "vpn", "mesh", "network"])

        let github = plugins.first(where: { $0.id == "github-notifications" })
        #expect(github?.name == "GitHub Notifications")
        #expect(github?.icon == "bell.badge.fill")
        #expect(github?.tags == ["github", "notifications", "pr", "dev"])

        let symbian = plugins.first(where: { $0.id == "symbian-belle-sync" })
        #expect(symbian?.name == "Nokia Belle USB Sync")
        #expect(symbian?.type == .desktop)
    }

    @Test("DMSPlugin decodes legacy JSON without isLocal as false")
    func testPluginLegacyDecoding() throws {
        let json = """
        {"id":"x","name":"X","description":"d","author":"a","version":"1.0.0","type":"widget","isInstalled":true,"isEnabled":false,"icon":"puzzlepiece.extension","repoURL":null,"tags":[],"isOfficial":true}
        """
        let plugin = try JSONDecoder().decode(DMSPlugin.self, from: Data(json.utf8))
        #expect(plugin.isLocal == false)
        #expect(plugin.isOfficial == true)

        let roundTripped = try JSONDecoder().decode(DMSPlugin.self, from: JSONEncoder().encode(plugin))
        #expect(roundTripped == plugin)
    }

    @Test("Manifest decodes minimal JSON with defaults, clamps interval, converts to plugin")
    func testPluginManifest() throws {
        let minimal = """
        {"id":"my-script","name":"My Script","description":"Does things","command":"/bin/echo hi"}
        """
        let manifest = try JSONDecoder().decode(DMSPluginManifest.self, from: Data(minimal.utf8))
        #expect(manifest.id == "my-script")
        #expect(manifest.author == "Local")
        #expect(manifest.version == "1.0.0")
        #expect(manifest.type == .barWidget)
        #expect(manifest.icon == "puzzlepiece.extension")
        #expect(manifest.intervalSeconds == 30)
        #expect(manifest.clampedInterval == 30)
        #expect(manifest.onClick == nil)
        #expect(manifest.launcherPrefix == nil)

        let low = DMSPluginManifest(id: "a", name: "a", description: "d", command: "c", intervalSeconds: 1)
        #expect(low.clampedInterval == 5)
        let high = DMSPluginManifest(id: "a", name: "a", description: "d", command: "c", intervalSeconds: 99999)
        #expect(high.clampedInterval == 3600)

        let plugin = manifest.toPlugin(isEnabled: true)
        #expect(plugin.id == "my-script")
        #expect(plugin.name == "My Script")
        #expect(plugin.isInstalled == true)
        #expect(plugin.isEnabled == true)
        #expect(plugin.isOfficial == false)
        #expect(plugin.isLocal == true)
        #expect(plugin.repoURL == nil)
    }

    @Test("Widget output parses JSON, plain multiline text, and empty input")
    func testPluginWidgetOutputParse() {
        let json = ##"{"text":"CPU 12%","icon":"cpu","color":"#FF9E00","tooltip":"Usage"}"##
        let parsed = DMSPluginWidgetOutput.parse(stdout: json)
        #expect(parsed?.text == "CPU 12%")
        #expect(parsed?.icon == "cpu")
        #expect(parsed?.color == "#FF9E00")
        #expect(parsed?.tooltip == "Usage")

        let plain = DMSPluginWidgetOutput.parse(stdout: "first line\nsecond line\n")
        #expect(plain?.text == "first line")
        #expect(plain?.icon == nil)
        #expect(plain?.color == nil)
        #expect(plain?.tooltip == nil)

        let long = String(repeating: "a", count: 100)
        let clamped = DMSPluginWidgetOutput.parse(stdout: long)
        #expect(clamped?.text.count == 64)

        #expect(DMSPluginWidgetOutput.parse(stdout: "") == nil)
        #expect(DMSPluginWidgetOutput.parse(stdout: "   \n\t  ") == nil)
    }
}
