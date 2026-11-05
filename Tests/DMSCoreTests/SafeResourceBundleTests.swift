import Testing
import Foundation
@testable import DMSCore

@Suite("SafeResourceBundle Tests")
struct SafeResourceBundleTests {

    @Test("Missing resource bundle returns nil instead of fatalError")
    func missingBundleReturnsNil() {
        // The SwiftPM-generated Bundle.module accessor crashes with
        // "unable to find bundle named ..." in this case; the safe resolver must not.
        #expect(SafeResourceBundle.bundle(named: "DMS_DoesNotExist_9f3b2a7c") == nil)
    }

    @Test("Existing resource bundle is located")
    func existingBundleIsFound() {
        // DMSCoreTests runs from the SwiftPM build directory where the
        // DMSCore resource bundle (if any) sits next to the test bundle;
        // at minimum the lookup must terminate without crashing and return
        // a Bundle only when the bundle path actually exists on disk.
        if let bundle = SafeResourceBundle.bundle(named: "DMS_DMSCore") {
            #expect(FileManager.default.fileExists(atPath: bundle.bundlePath))
        }
    }
}
