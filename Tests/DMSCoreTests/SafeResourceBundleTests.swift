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

    private static func writeTestBundle(at bundleDir: URL) throws {
        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>com.dms.test</string>
        <key>CFBundleName</key><string>Test</string>
        <key>CFBundlePackageType</key><string>BNDL</string>
        </dict></plist>
        """
        try plist.write(to: bundleDir.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
    }

    @Test("Symlinked .app/Contents/MacOS/<exe> resolves Contents/Resources/<name>.bundle")
    func symlinkedAppExecutableFindsResourcesBundle() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dms_srb_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let fm = FileManager.default

        let app = tmp.appendingPathComponent("Test.app")
        let macos = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
        let resources = app.appendingPathComponent("Contents/Resources", isDirectory: true)
        try fm.createDirectory(at: macos, withIntermediateDirectories: true)
        try fm.createDirectory(at: resources, withIntermediateDirectories: true)

        // Real bundle inside Contents/Resources.
        let bundleDir = resources.appendingPathComponent("DMS_Test.bundle")
        try Self.writeTestBundle(at: bundleDir)

        // Real executable target inside Contents/Resources, symlinked from Contents/MacOS:
        // Test.app/Contents/MacOS/dms -> Test.app/Contents/Resources/dms-real
        let realExe = resources.appendingPathComponent("dms-real")
        try "binary".write(to: realExe, atomically: true, encoding: .utf8)
        let exeLink = macos.appendingPathComponent("dms")
        try fm.createSymbolicLink(at: exeLink, withDestinationURL: realExe)

        let candidates = SafeResourceBundle.candidateDirectories(executableURL: exeLink, bundleURL: app)
        let bundle = SafeResourceBundle.bundle(named: "DMS_Test", in: candidates)
        #expect(bundle != nil)
        if let bundle {
            #expect(
                bundle.bundleURL.resolvingSymlinksInPath().path
                    == bundleDir.resolvingSymlinksInPath().path
            )
        }
    }

    @Test("A candidate whose bundle path exists but fails to load does not stop the search")
    func invalidFirstCandidateFallsThrough() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dms_srb2_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let fm = FileManager.default

        let dirA = tmp.appendingPathComponent("a", isDirectory: true)
        let dirB = tmp.appendingPathComponent("b", isDirectory: true)
        try fm.createDirectory(at: dirA, withIntermediateDirectories: true)
        try fm.createDirectory(at: dirB, withIntermediateDirectories: true)

        // dirA contains DMS_Bad.bundle as a plain *file* — Bundle(url:) returns nil for it.
        try "not a bundle".write(to: dirA.appendingPathComponent("DMS_Bad.bundle"), atomically: true, encoding: .utf8)
        // dirB contains a valid bundle directory.
        try Self.writeTestBundle(at: dirB.appendingPathComponent("DMS_Bad.bundle"))

        let bundle = SafeResourceBundle.bundle(named: "DMS_Bad", in: [dirA, dirB])
        #expect(bundle != nil)
        if let bundle {
            #expect(
                bundle.bundleURL.deletingLastPathComponent().resolvingSymlinksInPath().path
                    == dirB.resolvingSymlinksInPath().path
            )
        }
    }
}
