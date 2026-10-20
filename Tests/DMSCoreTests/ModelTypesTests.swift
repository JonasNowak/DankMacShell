import Testing
import Foundation
@testable import DMSCore

@Suite("Core Data Models Tests")
struct ModelTypesTests {

    @Test("WeatherData Condition Descriptions and SF Symbols")
    func testWeatherDataConditions() {
        // Test temperature Fahrenheit conversion
        let zeroC = WeatherData(temperatureC: 0.0)
        #expect(abs(zeroC.temperatureF - 32.0) < 0.001)

        let hundredC = WeatherData(temperatureC: 100.0)
        #expect(abs(hundredC.temperatureF - 212.0) < 0.001)

        // Weather codes mapping to condition descriptions
        let codesAndDescriptions: [(Int, String)] = [
            (0, "Clear Sky"),
            (1, "Mainly Clear"),
            (2, "Partly Cloudy"),
            (3, "Overcast"),
            (45, "Fog"),
            (48, "Fog"),
            (51, "Drizzle"),
            (61, "Rain"),
            (66, "Freezing Rain"),
            (71, "Snow Fall"),
            (77, "Snow Grains"),
            (80, "Rain Showers"),
            (85, "Snow Showers"),
            (95, "Thunderstorm"),
            (96, "Thunderstorm with Hail"),
            (99, "Thunderstorm with Hail"),
            (999, "Fair")
        ]

        for (code, expectedDesc) in codesAndDescriptions {
            let data = WeatherData(weatherCode: code)
            #expect(data.conditionDescription == expectedDesc)
        }

        // SF Symbols Day vs Night
        let sunDay = WeatherData(weatherCode: 0, isDay: true)
        #expect(sunDay.sfSymbol == "sun.max.fill")

        let moonNight = WeatherData(weatherCode: 0, isDay: false)
        #expect(moonNight.sfSymbol == "moon.stars.fill")

        let cloudyDay = WeatherData(weatherCode: 1, isDay: true)
        #expect(cloudyDay.sfSymbol == "cloud.sun.fill")

        let cloudyNight = WeatherData(weatherCode: 2, isDay: false)
        #expect(cloudyNight.sfSymbol == "cloud.moon.fill")

        let overcast = WeatherData(weatherCode: 3)
        #expect(overcast.sfSymbol == "cloud.fill")

        let fog = WeatherData(weatherCode: 45)
        #expect(fog.sfSymbol == "cloud.fog.fill")

        let rain = WeatherData(weatherCode: 65)
        #expect(rain.sfSymbol == "cloud.heavyrain.fill")

        let snow = WeatherData(weatherCode: 71)
        #expect(snow.sfSymbol == "snowflake")

        let thunder = WeatherData(weatherCode: 95)
        #expect(thunder.sfSymbol == "cloud.bolt.rain.fill")
    }

    @Test("WeatherData Codable Roundtrip")
    func testWeatherDataCodable() throws {
        let original = WeatherData(
            temperatureC: 21.5,
            apparentTemperatureC: 20.0,
            weatherCode: 1,
            humidity: 65,
            windSpeedKmh: 14.2,
            isDay: true,
            locationName: "Cupertino"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WeatherData.self, from: data)
        #expect(decoded == original)
    }

    @Test("NowPlayingTrack Formatting and Progress Bounds")
    func testNowPlayingBounds() {
        // Zero duration should return 0.0 progress without division by zero crash
        let zeroDuration = NowPlayingTrack(durationSeconds: 0.0, elapsedSeconds: 10.0)
        #expect(zeroDuration.progress == 0.0)

        // Negative elapsed clamped to 0.0
        let negativeElapsed = NowPlayingTrack(durationSeconds: 100.0, elapsedSeconds: -20.0)
        #expect(negativeElapsed.progress == 0.0)

        // Elapsed beyond duration clamped to 1.0
        let overElapsed = NowPlayingTrack(durationSeconds: 100.0, elapsedSeconds: 150.0)
        #expect(overElapsed.progress == 1.0)

        // Formatting
        let t1 = NowPlayingTrack(durationSeconds: 3665.0, elapsedSeconds: 65.0)
        #expect(t1.formattedDuration == "61:05")
        #expect(t1.formattedElapsed == "1:05")
    }

    @Test("SystemTelemetry Model and Defaults")
    func testSystemTelemetry() throws {
        let def = SystemTelemetry()
        #expect(def.cpuPercent == 0.0)
        #expect(def.ramPercent == 0.0)
        #expect(def.batteryPercent == nil)
        #expect(def.isCharging == false)

        let custom = SystemTelemetry(
            cpuPercent: 32.4,
            ramPercent: 68.1,
            ramUsedGB: 10.9,
            ramTotalGB: 16.0,
            batteryPercent: 88,
            isCharging: true,
            timeRemainingMinutes: 240,
            gpuPercent: 15.0
        )
        let data = try JSONEncoder().encode(custom)
        let decoded = try JSONDecoder().decode(SystemTelemetry.self, from: data)
        #expect(decoded == custom)
    }

    @Test("ProcessInfoItem Model")
    func testProcessInfoItem() throws {
        let proc = ProcessInfoItem(
            pid: 4321,
            name: "DankMaterialShell",
            cpuPercent: 1.2,
            memoryMB: 48.5,
            user: "jonasnowak"
        )
        #expect(proc.id == 4321)
        #expect(proc.pid == 4321)
        #expect(proc.name == "DankMaterialShell")

        let data = try JSONEncoder().encode(proc)
        let decoded = try JSONDecoder().decode(ProcessInfoItem.self, from: data)
        #expect(decoded == proc)
    }

    @Test("Workspace App Items and Tiling Window IDs")
    func testWorkspaceAppItems() {
        // With omniWMWindowID
        let tilingApp = WorkspaceAppItem(
            pid: 100,
            name: "Terminal",
            bundleID: "com.apple.Terminal",
            path: "/path",
            omniWMWindowID: "window_99"
        )
        #expect(tilingApp.id == "window_99")

        // Without omniWMWindowID falls back to pid_bundleID
        let regularApp = WorkspaceAppItem(
            pid: 200,
            name: "Safari",
            bundleID: "com.apple.Safari",
            path: "/path"
        )
        #expect(regularApp.id == "200_com.apple.Safari")

        // WorkspaceInfo
        let ws = WorkspaceInfo(id: "ws_1", number: 1, name: "Workspace 1", isCurrent: true, apps: [tilingApp, regularApp])
        #expect(ws.id == "ws_1")
        #expect(ws.apps.count == 2)
    }

    @Test("Plugin and Applet Catalogs")
    func testPluginAndAppletCatalogs() {
        // Plugin Types
        for type in DMSPluginType.allCases {
            #expect(!type.title.isEmpty)
            #expect(!type.icon.isEmpty)
        }

        // Standard plugins
        #expect(!DMSPluginRegistry.standardPlugins.isEmpty)
        for plugin in DMSPluginRegistry.standardPlugins {
            #expect(!plugin.id.isEmpty)
            #expect(!plugin.name.isEmpty)
            #expect(!plugin.version.isEmpty)
        }

        // Standard Applets
        #expect(!StandardApplets.all.isEmpty)
        for applet in StandardApplets.all {
            #expect(!applet.id.isEmpty)
            #expect(!applet.name.isEmpty)
        }

        // Applet positions
        #expect(DMSApplet.DMSAppletPosition.allCases.count == 3)
    }

    @Test("ControlCenterWidgetConfig Defaults and Codable")
    func testControlCenterWidgetConfig() throws {
        let defaults = ControlCenterWidgetConfig.defaultWidgets
        #expect(defaults.count >= 10)
        #expect(defaults.contains(where: { $0.id == "user" }))
        #expect(defaults.contains(where: { $0.id == "settings" }))
        #expect(defaults.contains(where: { $0.id == "volumeSlider" }))

        let customWidget = ControlCenterWidgetConfig(id: "customTile", col: 2, row: 3, w: 4, h: 2, small: false)
        let data = try JSONEncoder().encode(customWidget)
        let decoded = try JSONDecoder().decode(ControlCenterWidgetConfig.self, from: data)
        #expect(decoded == customWidget)
    }
}
