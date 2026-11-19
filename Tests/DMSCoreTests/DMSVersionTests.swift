import Testing
import Foundation
@testable import DMSCore

@Suite("DMSVersion Tests")
struct DMSVersionTests {

    @Test("Current version is 0.9.0")
    func testCurrentVersion() {
        #expect(DMSVersion.current == "0.9.0")
    }

    @Test("Display version is non-empty")
    func testDisplayVersion() {
        #expect(!DMSVersion.displayVersion.isEmpty)
    }

    @Test("User agent contains current version")
    func testUserAgent() {
        #expect(DMSVersion.userAgent.contains(DMSVersion.current))
    }
}
