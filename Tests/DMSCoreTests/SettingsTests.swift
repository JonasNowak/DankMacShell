import Testing
import Foundation
@testable import DMSCore

@Suite("Settings Specification & Models Tests")
struct SettingsTests {

    @Test("Settings Categories and Non-Empty Tab Hierarchy")
    func testCategoriesAndTabs() {
        let categories = SettingsCategory.allCases
        #expect(!categories.isEmpty)
        #expect(categories.contains(.personalization))
        #expect(categories.contains(.primaryBar))
        #expect(categories.contains(.widgetsNotifications))
        #expect(categories.contains(.dockLauncher))
        #expect(categories.contains(.keyboardShortcuts))
        #expect(categories.contains(.power))
        #expect(categories.contains(.plugins))
        #expect(categories.contains(.about))

        // Ensure every category has at least one tab
        for cat in categories {
            let tabs = SettingsTab.tabs(for: cat)
            #expect(!tabs.isEmpty, "Category \(cat.rawValue) should have at least one tab")
        }

        // Ensure tab IDs are unique
        let allTabs = SettingsTab.allCases
        let ids = allTabs.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count, "Tab IDs must be globally unique")
    }

    @Test("Settings Deep-Link and Alias Resolution")
    func testDeepLinkResolution() {
        // Direct matching
        #expect(SettingsTab.resolve(tab: "theme") == .theme)
        #expect(SettingsTab.resolve(tab: "Theme & Colors") == .theme)
        #expect(SettingsTab.resolve(tab: "wallpaper") == .wallpaper)
        #expect(SettingsTab.resolve(tab: "island") == .island)
        #expect(SettingsTab.resolve(tab: "Dank Island") == .island)
        #expect(SettingsTab.resolve(tab: "dock") == .dock)
        #expect(SettingsTab.resolve(tab: "launcher") == .launcher)
        #expect(SettingsTab.resolve(tab: "plugins") == .plugins)
        #expect(SettingsTab.resolve(tab: "shortcuts") == .shortcuts)
        #expect(SettingsTab.resolve(tab: "power") == .power)

        // Aliases
        #expect(SettingsTab.resolve(tab: "applets") == .barWidgets)
        #expect(SettingsTab.resolve(tab: "barwidgets") == .barWidgets)
        #expect(SettingsTab.resolve(tab: "appearance") == .theme)
        #expect(SettingsTab.resolve(tab: "keybinds") == .shortcuts)
        #expect(SettingsTab.resolve(tab: "hotkeys") == .shortcuts)
        #expect(SettingsTab.resolve(tab: "diagnostics") == .about)
        #expect(SettingsTab.resolve(tab: "doctor") == .about)
        #expect(SettingsTab.resolve(tab: "dash") == .dashboard)

        // Case insensitivity
        #expect(SettingsTab.resolve(tab: "ISLAND") == .island)
        #expect(SettingsTab.resolve(tab: "PlUgInS") == .plugins)

        // Unknown fallback
        #expect(SettingsTab.resolve(tab: "nonexistent_tab_123") == .theme)
        #expect(SettingsTab.resolve(tab: nil) == .theme)
    }

    @Test("Settings Search Index and Filtering")
    func testSearchIndexing() {
        // Empty query returns all tabs
        let all = SettingsSearchIndex.filter(query: "")
        #expect(all.count == SettingsTab.allCases.count)

        // Exact tab name
        let islandResults = SettingsSearchIndex.filter(query: "island")
        #expect(islandResults.contains(.island))

        // Keyword search: "celsius" should find time & weather
        let weatherResults = SettingsSearchIndex.filter(query: "celsius")
        #expect(weatherResults.contains(.timeWeather))

        // Keyword search: "matugen" or "seed" should find theme
        let themeResults = SettingsSearchIndex.filter(query: "seed")
        #expect(themeResults.contains(.theme))

        // Keyword search: "magnification" should find dock
        let dockResults = SettingsSearchIndex.filter(query: "magnification")
        #expect(dockResults.contains(.dock))

        // Keyword search: "caffeinate" should find power
        let powerResults = SettingsSearchIndex.filter(query: "caffeinate")
        #expect(powerResults.contains(.power))

        // Non-matching query returns empty
        let emptyResults = SettingsSearchIndex.filter(query: "xyznonexistentstring12345")
        #expect(emptyResults.isEmpty)
    }

    @Test("No Redundant macOS Settings Included")
    func testNoMacOSRedundancies() {
        // macOS already covers Wi-Fi scanning/connections, Bluetooth pairing,
        // System Display arrangement canvas, Gamma control, Printers, etc.
        // Verify those are NOT present as top-level settings tabs.
        let tabIds = Set(SettingsTab.allCases.map { $0.id.lowercased() })
        #expect(!tabIds.contains("wifi"))
        #expect(!tabIds.contains("bluetooth"))
        #expect(!tabIds.contains("network"))
        #expect(!tabIds.contains("displays"))
        #expect(!tabIds.contains("gammacontrol"))
        #expect(!tabIds.contains("printers"))
    }

    @Test("Widget Catalog and BarLayout Operations")
    func testWidgetCatalogAndBarLayout() {
        let catalog = SettingsWidgetCatalog.all
        #expect(!catalog.isEmpty)
        #expect(catalog.contains(where: { $0.id == "diskUsage" }))
        #expect(catalog.contains(where: { $0.id == "cpuTemperature" }))
        #expect(catalog.contains(where: { $0.id == "systemTray" }))
        #expect(catalog.contains(where: { $0.id == "privacyIndicator" }))
        #expect(catalog.contains(where: { $0.id == "clock" }))
        #expect(catalog.contains(where: { $0.id == "mediaControls" }))

        var layout = BarLayout(
            left: [BarWidgetEntry(id: "launcherButton", widgetId: "launcherButton", enabled: true)],
            center: [BarWidgetEntry(id: "clock", widgetId: "clock", enabled: true)],
            right: [BarWidgetEntry(id: "battery", widgetId: "battery", enabled: true)]
        )

        // Add widget to section
        SettingsWidgetCatalog.addWidget(to: .left, widgetId: "workspaceSwitcher", in: &layout)
        #expect(layout.left.count == 2)
        #expect(layout.left.last?.widgetId == "workspaceSwitcher")

        // Toggle widget enabled/disabled
        SettingsWidgetCatalog.toggleWidget(id: "clock", in: &layout)
        #expect(layout.center.first?.enabled == false)
        SettingsWidgetCatalog.toggleWidget(id: "clock", in: &layout)
        #expect(layout.center.first?.enabled == true)

        // Remove widget
        SettingsWidgetCatalog.removeWidget(id: "launcherButton", in: &layout)
        #expect(layout.left.count == 1)
        #expect(layout.left.first?.widgetId == "workspaceSwitcher")

        // Reorder widgets
        SettingsWidgetCatalog.addWidget(to: .right, widgetId: "volume", in: &layout)
        SettingsWidgetCatalog.addWidget(to: .right, widgetId: "wifi", in: &layout)
        #expect(layout.right.map { $0.widgetId } == ["battery", "volume", "wifi"])

        SettingsWidgetCatalog.moveWidget(in: .right, fromIndex: 2, toIndex: 0, in: &layout)
        #expect(layout.right.map { $0.widgetId } == ["wifi", "battery", "volume"])
    }

    @Test("Island Settings Defaults, Geometry Clamping, and Serialization")
    func testIslandSettings() {
        var island = IslandSettings.default
        #expect(island.instance == .off || island.instance == .mainBar)
        #expect(island.float == false)
        #expect(island.useOverlayLayer == false)
        #expect(island.reservedHeight >= 0)
        #expect(island.compactIslandHeight >= 20)

        // Clamping checks
        island.reservedHeight = -10
        #expect(island.reservedHeight == 0)

        island.reservedHeight = 200
        #expect(island.reservedHeight == 120) // max clamp

        island.compactIslandHeight = 10
        #expect(island.compactIslandHeight == 24) // min clamp

        island.compactIslandHeight = 100
        #expect(island.compactIslandHeight == 64) // max clamp

        island.outerGaps = -5
        #expect(island.outerGaps == 0)

        island.outerGaps = 80
        #expect(island.outerGaps == 48)

        // Home compact shortcuts
        island.mediaLauncher = .left
        island.batteryControlCenter = .hidden
        island.weather = .right
        island.compactClockPill = true

        // Encoding & decoding dictionary roundtrip
        let dict = island.toDictionary()
        let restored = IslandSettings(from: dict)
        #expect(restored.mediaLauncher == .left)
        #expect(restored.batteryControlCenter == .hidden)
        #expect(restored.weather == .right)
        #expect(restored.compactClockPill == true)
        #expect(restored.reservedHeight == island.reservedHeight)
        #expect(restored.compactIslandHeight == island.compactIslandHeight)
    }

    @Test("Plugin Browser Filtering and Third-Party Toggle")
    func testPluginBrowserFiltering() {
        let samplePlugins = [
            DMSPlugin(
                id: "dank-actions",
                name: "Dank Actions",
                description: "Add customizable scriptable actions to your bar",
                author: "Avenge Media",
                version: "1.0.0",
                type: .barWidget,
                isInstalled: true,
                isEnabled: true,
                icon: "sparkles",
                repoURL: nil,
                tags: ["dankbar-widget"],
                isOfficial: true
            ),
            DMSPlugin(
                id: "power-usage-monitor",
                name: "Power Usage Monitor",
                description: "Real-time watt sensor readout",
                author: "Community",
                version: "0.2.1",
                type: .barWidget,
                isInstalled: false,
                isEnabled: false,
                icon: "bolt.fill",
                repoURL: nil,
                tags: ["hardware"],
                isOfficial: false
            ),
            DMSPlugin(
                id: "pomodoro-timer",
                name: "Dank Pomodoro Timer",
                description: "A customizable Pomodoro timer",
                author: "Avenge Media",
                version: "1.1.0",
                type: .barWidget,
                isInstalled: false,
                isEnabled: false,
                icon: "timer",
                repoURL: nil,
                tags: ["dankbar-widget"],
                isOfficial: true
            )
        ]

        // Filter: no query, show all
        let all = PluginFilter.filter(plugins: samplePlugins, query: "", hideThirdParty: false)
        #expect(all.count == 3)

        // Filter: hide 3rd party
        let officialOnly = PluginFilter.filter(plugins: samplePlugins, query: "", hideThirdParty: true)
        #expect(officialOnly.count == 2)
        #expect(officialOnly.allSatisfy { $0.isOfficial })

        // Filter: text query "watt"
        let watt = PluginFilter.filter(plugins: samplePlugins, query: "watt", hideThirdParty: false)
        #expect(watt.count == 1)
        #expect(watt.first?.id == "power-usage-monitor")

        // Filter: text query "watt" + hide 3rd party -> empty
        let wattOfficial = PluginFilter.filter(plugins: samplePlugins, query: "watt", hideThirdParty: true)
        #expect(wattOfficial.isEmpty)

        // Filter: tag search "dankbar-widget"
        let tagged = PluginFilter.filter(plugins: samplePlugins, query: "dankbar-widget", hideThirdParty: false)
        #expect(tagged.count == 2)
    }
}
