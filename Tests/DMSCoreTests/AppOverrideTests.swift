import Testing
import Foundation
@testable import DMSCore

@Suite("App Override Entries and Applier Tests (v0.6 LAUNCH)")
struct AppOverrideTests {

    private func sampleApp() -> AppItem {
        AppItem(
            name: "Safari",
            bundleID: "com.apple.Safari",
            path: "/Applications/Safari.app",
            subtitle: "Browse the World Wide Web",
            category: "Web"
        )
    }

    @Test("Override Application: Display Name, Hidden, Untouched")
    func testApplyOverrides() {
        let app = sampleApp()

        // No override -> unchanged
        #expect(AppOverrideApplier.apply([:], to: app) == app)

        // Display name override
        let renamed = AppOverrideApplier.apply(
            ["com.apple.Safari": AppOverrideEntry(displayName: "Web Browser")],
            to: app
        )
        #expect(renamed?.name == "Web Browser")
        #expect(renamed?.bundleID == "com.apple.Safari")

        // Blank display name falls back to original
        let blank = AppOverrideApplier.apply(
            ["com.apple.Safari": AppOverrideEntry(displayName: "   ")],
            to: app
        )
        #expect(blank?.name == "Safari")

        // Hidden -> nil
        let hidden = AppOverrideApplier.apply(
            ["com.apple.Safari": AppOverrideEntry(hiddenFromLauncher: true)],
            to: app
        )
        #expect(hidden == nil)
    }

    @Test("Tags and Launch Arguments Lookup")
    func testTagsAndArgs() {
        let overrides: [String: AppOverrideEntry] = [
            "com.apple.Safari": AppOverrideEntry(launchArguments: ["--incognito"], tags: ["web", "browser"])
        ]
        #expect(AppOverrideApplier.tags(overrides, for: "com.apple.Safari") == ["web", "browser"])
        #expect(AppOverrideApplier.launchArguments(overrides, for: "com.apple.Safari") == ["--incognito"])
        #expect(AppOverrideApplier.tags(overrides, for: "com.apple.Terminal").isEmpty)
        #expect(AppOverrideApplier.launchArguments(overrides, for: "com.apple.Terminal") == nil)
    }

    @Test("isDefault Detection for Entry Removal")
    func testIsDefault() {
        #expect(AppOverrideEntry().isDefault)
        #expect(AppOverrideEntry(displayName: " ").isDefault)
        #expect(!AppOverrideEntry(displayName: "X").isDefault)
        #expect(!AppOverrideEntry(launchArguments: []).isDefault == false) // empty args array is default
        #expect(AppOverrideEntry(launchArguments: []).isDefault)
        #expect(!AppOverrideEntry(hiddenFromLauncher: true).isDefault)
        #expect(!AppOverrideEntry(tags: ["a"]).isDefault)
    }

    @Test("Shell Argument Splitting with Quotes and Escapes")
    func testSplitShellArguments() {
        #expect(AppOverrideApplier.splitShellArguments("") == [])
        #expect(AppOverrideApplier.splitShellArguments("   ") == [])
        #expect(AppOverrideApplier.splitShellArguments("--incognito") == ["--incognito"])
        #expect(AppOverrideApplier.splitShellArguments("-a 1 -b 2") == ["-a", "1", "-b", "2"])
        #expect(AppOverrideApplier.splitShellArguments("--name \"My App\"") == ["--name", "My App"])
        #expect(AppOverrideApplier.splitShellArguments("--path '/Users/a b/c'") == ["--path", "/Users/a b/c"])
        #expect(AppOverrideApplier.splitShellArguments("--msg \"say \\\"hi\\\"\"") == ["--msg", "say \"hi\""])
        #expect(AppOverrideApplier.splitShellArguments("--esc a\\ b") == ["--esc", "a b"])
        #expect(AppOverrideApplier.splitShellArguments("  --x   'y z'  ") == ["--x", "y z"])
    }

    @Test("AppOverrideEntry Codable Round-Trip and Legacy Decoding")
    func testCodable() throws {
        let entry = AppOverrideEntry(
            displayName: "Browser",
            launchArguments: ["--incognito"],
            hiddenFromLauncher: true,
            tags: ["web"]
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(AppOverrideEntry.self, from: data)
        #expect(decoded == entry)
        // Persisted key for the hidden flag is "hidden"
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\"hidden\":true"))

        // Legacy JSON without any of the new keys decodes to a default entry
        let legacy = try JSONDecoder().decode(AppOverrideEntry.self, from: Data("{}".utf8))
        #expect(legacy.isDefault)
    }
}
