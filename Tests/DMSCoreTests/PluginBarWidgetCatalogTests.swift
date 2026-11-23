import Testing
import Foundation
@testable import DMSCore

@Suite("Plugin Bar Widget Catalog Tests (v0.9.9)")
struct PluginBarWidgetCatalogTests {

    @Test("Catalog contains first-class plugin widget metadata entries")
    func testCatalogContainsPluginWidgetEntries() {
        let pomodoro = SettingsWidgetCatalog.all.first(where: { $0.id == "pomodoro" })
        #expect(pomodoro != nil)
        #expect(pomodoro?.name == "Pomodoro Timer")
        #expect(pomodoro?.description == "Focus & break countdown timer with popout controls")
        #expect(pomodoro?.icon == "timer")

        let tailscale = SettingsWidgetCatalog.all.first(where: { $0.id == "tailscale" })
        #expect(tailscale != nil)
        #expect(tailscale?.name == "Tailscale Mesh")
        #expect(tailscale?.description == "Tailscale VPN status, exit node picker & mesh peers popout")
        #expect(tailscale?.icon == "network.badge.shield.half.filled")

        let github = SettingsWidgetCatalog.all.first(where: { $0.id == "githubNotifications" })
        #expect(github != nil)
        #expect(github?.name == "GitHub Notifications")
        #expect(github?.description == "Unread GitHub notifications counter & feed popout")
        #expect(github?.icon == "bell.badge.fill")
    }

    @Test("barWidgetID(forPluginID:) maps built-in plugins and falls back to plugin:<id>")
    func testBarWidgetIDMapping() {
        #expect(SettingsWidgetCatalog.barWidgetID(forPluginID: "pomodoro-timer") == "pomodoro")
        #expect(SettingsWidgetCatalog.barWidgetID(forPluginID: "tailscale-status") == "tailscale")
        #expect(SettingsWidgetCatalog.barWidgetID(forPluginID: "github-notifications") == "githubNotifications")
        #expect(SettingsWidgetCatalog.barWidgetID(forPluginID: "my-local-plugin") == "plugin:my-local-plugin")
        #expect(SettingsWidgetCatalog.barWidgetID(forPluginID: "") == "plugin:")
    }

    @Test("pluginID(forBarWidgetID:) is the inverse mapping and nil for built-in widgets")
    func testPluginIDInverseMapping() {
        #expect(SettingsWidgetCatalog.pluginID(forBarWidgetID: "pomodoro") == "pomodoro-timer")
        #expect(SettingsWidgetCatalog.pluginID(forBarWidgetID: "tailscale") == "tailscale-status")
        #expect(SettingsWidgetCatalog.pluginID(forBarWidgetID: "githubNotifications") == "github-notifications")
        #expect(SettingsWidgetCatalog.pluginID(forBarWidgetID: "plugin:my-local-plugin") == "my-local-plugin")
        #expect(SettingsWidgetCatalog.pluginID(forBarWidgetID: "battery") == nil)
        #expect(SettingsWidgetCatalog.pluginID(forBarWidgetID: "clock") == nil)
        #expect(SettingsWidgetCatalog.pluginID(forBarWidgetID: "vpn") == nil)
    }

    @Test("barWidgetID / pluginID round-trip for built-in and local plugins")
    func testRoundTrip() {
        let pluginIDs = ["pomodoro-timer", "tailscale-status", "github-notifications", "some-local-plugin"]
        for pluginID in pluginIDs {
            let widgetID = SettingsWidgetCatalog.barWidgetID(forPluginID: pluginID)
            #expect(SettingsWidgetCatalog.pluginID(forBarWidgetID: widgetID) == pluginID)
        }
    }

    @Test("meta(for:plugins:) resolves built-in catalog entries first")
    func testMetaResolvesBuiltIns() {
        #expect(SettingsWidgetCatalog.meta(for: "pomodoro")?.name == "Pomodoro Timer")
        #expect(SettingsWidgetCatalog.meta(for: "tailscale")?.icon == "network.badge.shield.half.filled")
        #expect(SettingsWidgetCatalog.meta(for: "githubNotifications")?.name == "GitHub Notifications")
        #expect(SettingsWidgetCatalog.meta(for: "battery")?.name == "Battery")
        #expect(SettingsWidgetCatalog.meta(for: "does-not-exist") == nil)
        #expect(SettingsWidgetCatalog.meta(for: "plugin:unknown") == nil)
        #expect(SettingsWidgetCatalog.meta(for: "plugin:unknown", plugins: []) == nil)
    }

    @Test("meta(for:plugins:) falls back to local/custom plugin:<id> entries")
    func testMetaResolvesLocalPlugins() {
        let local = DMSPlugin(
            id: "my-local-plugin",
            name: "My Local Plugin",
            description: "A locally installed bar widget",
            author: "Local",
            version: "1.0.0",
            type: .barWidget,
            isInstalled: true,
            isEnabled: true,
            icon: "star.fill",
            isOfficial: false,
            isLocal: true
        )
        let meta = SettingsWidgetCatalog.meta(for: "plugin:my-local-plugin", plugins: [local])
        #expect(meta != nil)
        #expect(meta?.id == "plugin:my-local-plugin")
        #expect(meta?.name == "My Local Plugin")
        #expect(meta?.description == "A locally installed bar widget")
        #expect(meta?.icon == "star.fill")

        // Built-in catalog wins over a plugin list entry with the same widget id.
        let builtin = SettingsWidgetCatalog.meta(for: "pomodoro", plugins: [local])
        #expect(builtin?.name == "Pomodoro Timer")
    }
}
