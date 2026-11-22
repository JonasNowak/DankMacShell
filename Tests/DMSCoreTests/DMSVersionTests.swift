import Testing
import Foundation
@testable import DMSCore

@Suite("DMSVersion Tests")
struct DMSVersionTests {

    @Test("Current version is 0.9.8")
    func testCurrentVersion() {
        #expect(DMSVersion.current == "0.9.8")
    }

    @Test("Display version is non-empty")
    func testDisplayVersion() {
        #expect(!DMSVersion.displayVersion.isEmpty)
    }

    @Test("User agent contains current version")
    func testUserAgent() {
        #expect(DMSVersion.userAgent.contains(DMSVersion.current))
    }

    // MARK: - isNewerVersion(_:than:)

    @Test("isNewerVersion: standard semver core comparison")
    func testIsNewerVersionStandardSemver() {
        #expect(DMSVersion.isNewerVersion("1.0.1", than: "1.0.0"))
        #expect(DMSVersion.isNewerVersion("0.9.2", than: "0.9.1"))
        #expect(DMSVersion.isNewerVersion("2.0.0", than: "1.9.9"))
        // numeric, not lexicographic: 10 > 9
        #expect(DMSVersion.isNewerVersion("1.10.0", than: "1.9.0"))
        #expect(!DMSVersion.isNewerVersion("1.0.0", than: "1.0.0"))
        #expect(!DMSVersion.isNewerVersion("1.0.0", than: "1.0.1"))
        #expect(!DMSVersion.isNewerVersion("0.9.1", than: "0.9.2"))
    }

    @Test("isNewerVersion: missing minor/patch pad with 0")
    func testIsNewerVersionPadsMissingComponents() {
        #expect(!DMSVersion.isNewerVersion("1.0", than: "1.0.0"))
        #expect(!DMSVersion.isNewerVersion("1", than: "1.0.0"))
        #expect(!DMSVersion.isNewerVersion("1.0.0", than: "1"))
        #expect(DMSVersion.isNewerVersion("1.1", than: "1.0.9"))
        #expect(DMSVersion.isNewerVersion("1", than: "0.9.9"))
    }

    @Test("isNewerVersion: leading v/V prefix and surrounding whitespace are ignored")
    func testIsNewerVersionVPrefixAndWhitespace() {
        #expect(DMSVersion.isNewerVersion("v1.2.3", than: "1.2.2"))
        #expect(DMSVersion.isNewerVersion("V2.0.0", than: "v1.9.9"))
        #expect(!DMSVersion.isNewerVersion("v1.0.0", than: "1.0.0"))
        #expect(!DMSVersion.isNewerVersion("1.0.0", than: "v1.0.0"))
        #expect(DMSVersion.isNewerVersion("  1.2.0\n", than: "1.1.9"))
    }

    @Test("isNewerVersion: final release outranks any pre-release tag")
    func testIsNewerVersionFinalVsPreRelease() {
        #expect(DMSVersion.isNewerVersion("1.0.0", than: "1.0.0-beta.1"))
        #expect(DMSVersion.isNewerVersion("1.0.0", than: "1.0.0-dev.1"))
        #expect(DMSVersion.isNewerVersion("1.0.0", than: "1.0.0-rc.1"))
        #expect(!DMSVersion.isNewerVersion("1.0.0-beta.1", than: "1.0.0"))
        #expect(!DMSVersion.isNewerVersion("1.0.0-rc.1", than: "1.0.0"))
        // differing core numbers still dominate over pre-release tags
        #expect(DMSVersion.isNewerVersion("1.0.1-beta.1", than: "1.0.0"))
        #expect(!DMSVersion.isNewerVersion("0.9.9", than: "1.0.0-rc.1"))
    }

    @Test("isNewerVersion: pre-release tag ordering (dev / beta / rc)")
    func testIsNewerVersionPreReleaseOrdering() {
        // non-integer identifiers compare lexicographically: beta < dev < rc
        #expect(DMSVersion.isNewerVersion("1.0.0-dev.1", than: "1.0.0-beta.1"))
        #expect(DMSVersion.isNewerVersion("1.0.0-rc.1", than: "1.0.0-dev.1"))
        #expect(DMSVersion.isNewerVersion("1.0.0-rc.1", than: "1.0.0-beta.2"))
        #expect(!DMSVersion.isNewerVersion("1.0.0-beta.1", than: "1.0.0-dev.1"))
        #expect(!DMSVersion.isNewerVersion("1.0.0-dev.1", than: "1.0.0-rc.1"))
        // integer identifiers compare numerically: beta.10 > beta.2
        #expect(DMSVersion.isNewerVersion("1.0.0-beta.10", than: "1.0.0-beta.2"))
        #expect(!DMSVersion.isNewerVersion("1.0.0-beta.2", than: "1.0.0-beta.10"))
        #expect(!DMSVersion.isNewerVersion("1.0.0-rc.2", than: "1.0.0-rc.10"))
        // equal tags are not newer
        #expect(!DMSVersion.isNewerVersion("1.0.0-beta.1", than: "1.0.0-beta.1"))
        #expect(!DMSVersion.isNewerVersion("1.0.0-rc.1", than: "1.0.0-rc.1"))
    }

    @Test("isNewerVersion: build metadata (+...) is stripped")
    func testIsNewerVersionBuildMetadata() {
        #expect(!DMSVersion.isNewerVersion("1.0.0+build.5", than: "1.0.0"))
        #expect(!DMSVersion.isNewerVersion("1.0.0", than: "1.0.0+build.5"))
        #expect(DMSVersion.isNewerVersion("1.0.1+build.42", than: "1.0.0+build.7"))
        #expect(DMSVersion.isNewerVersion("v1.0.0-rc.1+build.123", than: "1.0.0-beta.9"))
        #expect(!DMSVersion.isNewerVersion("1.0.0-beta.1+build.9", than: "1.0.0-beta.1+build.1"))
    }
}

@Suite("DMSConfig Onboarding & Update Settings")
struct DMSConfigOnboardingSettingsTests {

    @Test("onboardingCompleted defaults to false and round-trips through rawSettings")
    func testOnboardingCompleted() {
        var config = DMSConfig()
        #expect(config.onboardingCompleted == false)
        config.onboardingCompleted = true
        #expect(config.onboardingCompleted == true)
        #expect(config.rawSettings["onboardingCompleted"]?.boolValue == true)
        config.onboardingCompleted = false
        #expect(config.onboardingCompleted == false)
    }

    @Test("checkForUpdatesAutomatically defaults to true and round-trips through rawSettings")
    func testCheckForUpdatesAutomatically() {
        var config = DMSConfig()
        #expect(config.checkForUpdatesAutomatically == true)
        config.checkForUpdatesAutomatically = false
        #expect(config.checkForUpdatesAutomatically == false)
        #expect(config.rawSettings["checkForUpdatesAutomatically"]?.boolValue == false)
    }

    @Test("launchAtLogin defaults to false and round-trips through rawSettings")
    func testLaunchAtLogin() {
        var config = DMSConfig()
        #expect(config.launchAtLogin == false)
        config.launchAtLogin = true
        #expect(config.launchAtLogin == true)
        #expect(config.rawSettings["launchAtLogin"]?.boolValue == true)
    }

    @Test("Onboarding & update settings decode from root-level JSON keys")
    func testOnboardingSettingsDecodeFromJSON() {
        let json = """
        {
            "onboardingCompleted": true,
            "checkForUpdatesAutomatically": false,
            "launchAtLogin": true
        }
        """
        let config = DMSConfig.load(from: json.data(using: .utf8)!)
        #expect(config.onboardingCompleted == true)
        #expect(config.checkForUpdatesAutomatically == false)
        #expect(config.launchAtLogin == true)
    }

    @Test("Onboarding & update settings survive an encode/decode round-trip")
    func testOnboardingSettingsRoundTrip() throws {
        var config = DMSConfig()
        config.onboardingCompleted = true
        config.checkForUpdatesAutomatically = false
        config.launchAtLogin = true
        let data = try config.encodeJSON()
        let decoded = DMSConfig.load(from: data)
        #expect(decoded.onboardingCompleted == true)
        #expect(decoded.checkForUpdatesAutomatically == false)
        #expect(decoded.launchAtLogin == true)
    }
}
