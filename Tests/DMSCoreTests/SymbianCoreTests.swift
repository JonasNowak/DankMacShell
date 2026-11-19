import Testing
import Foundation
@testable import DMSCore

@Suite("Symbian Belle USB Sync Core Engine Tests")
struct SymbianCoreTests {

    // MARK: - Test Helpers

    /// Creates a UUID-scoped temporary directory (callers clean it up in `defer`).
    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dms_symbian_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Builds a mock audio file with an ID3v2 tag (v2.2 6-byte or v2.3/2.4 10-byte frame headers).
    private func buildID3v2File(frames: [(id: String, text: String)], version: UInt8 = 3, payloadSize: Int = 1024) -> Data {
        var tagBody = Data()
        for frame in frames {
            guard let idData = frame.id.data(using: .ascii) else { continue }
            var body = Data([3]) // UTF-8 encoding flag
            body.append(frame.text.data(using: .utf8)!)
            if version == 2 {
                tagBody.append(idData) // 3-char frame ID
                let size = UInt32(body.count)
                tagBody.append(Data([UInt8((size >> 16) & 0xFF), UInt8((size >> 8) & 0xFF), UInt8(size & 0xFF)]))
            } else {
                tagBody.append(idData) // 4-char frame ID
                let size = UInt32(body.count).bigEndian
                tagBody.append(Data(bytes: [size], count: 4))
                tagBody.append(Data([0, 0])) // flags
            }
            tagBody.append(body)
        }
        var fileData = Data([0x49, 0x44, 0x33, version, 0x00, 0x00]) // "ID3" + version + flags
        let tagSize = tagBody.count
        fileData.append(contentsOf: [
            UInt8((tagSize >> 21) & 0x7F),
            UInt8((tagSize >> 14) & 0x7F),
            UInt8((tagSize >> 7) & 0x7F),
            UInt8(tagSize & 0x7F)
        ])
        fileData.append(tagBody)
        fileData.append(Data(repeating: 0xFF, count: payloadSize)) // simulated audio payload
        return fileData
    }

    // MARK: - 1. Device Model & Storage Tests

    @Test("SymbianDevice Model Formatting and Capacity Bounds")
    func testDeviceModel() {
        let dev = SymbianDevice(
            id: "/Volumes/NOKIA",
            name: "Nokia C7-00 (E:)",
            modelName: "C7-00",
            volumeName: "NOKIA",
            mountPath: "/Volumes/NOKIA",
            driveLetter: "E:",
            isInternalMassMemory: true,
            isRemovableCard: false,
            totalBytes: 8_000_000_000,
            freeBytes: 3_200_000_000,
            osVersion: "Nokia Belle (Symbian^3)",
            hasSymbianFileSystem: true
        )

        #expect(dev.usedBytes == 4_800_000_000)
        #expect(dev.usedPercentage > 0.59 && dev.usedPercentage < 0.61)
        #expect(dev.musicURL.path == "/Volumes/NOKIA/Music")
        #expect(dev.installsURL.path == "/Volumes/NOKIA/Installs")
        #expect(!dev.formattedTotalSpace.isEmpty)
        #expect(!dev.formattedFreeSpace.isEmpty)
    }

    // MARK: - 2. SIS/SISX Parser Tests

    @Test("SymbianSISParser Binary SISX Header Parsing")
    func testSISXParsing() throws {
        let tmpDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let tmp = tmpDir.appendingPathComponent("TestApp_v2.0_Belle.sisx")

        // Construct mock SISX binary with Symbian OS v9.x+ magic UIDs
        var data = Data()
        var uid1 = SymbianSISParser.sisxMagicUID1
        var uid2 = SymbianSISParser.sisxMagicUID2
        var uid3: UInt32 = 0x20038F10 // Unique Symbian Application UID
        var checksum: UInt16 = 0x1234

        data.append(Data(bytes: &uid1, count: 4))
        data.append(Data(bytes: &uid2, count: 4))
        data.append(Data(bytes: &uid3, count: 4))
        data.append(Data(bytes: &checksum, count: 2))
        data.append("Dummy Symbian Belle SISX payload".data(using: .utf8)!)

        try data.write(to: tmp)

        let parsed = SymbianSISParser.parse(url: tmp)
        #expect(parsed.packageType == .sisx)
        #expect(parsed.uid == "0x20038F10")
        #expect(parsed.targetPlatform.contains("Symbian Belle"))
        #expect(parsed.appName.contains("TestApp"))
        #expect(parsed.version == "2.0")
    }

    @Test("SymbianSISParser Filename Cleaning and Version Extraction")
    func testFilenameCleaning() {
        let name1 = SymbianSISParser.cleanNameFromFilename("AngryBirds_v1_2_1_Belle.sisx")
        #expect(name1 == "AngryBirds")

        let name2 = SymbianSISParser.cleanNameFromFilename("Opera_Mini_7.1_Symbian3.sisx")
        #expect(name2.contains("Opera Mini"))

        let ver1 = SymbianSISParser.extractVersionFromFilename("WhatsApp_v2.12.45_signed.sisx")
        #expect(ver1 == "2.12.45")
    }

    @Test("SymbianSISParser JAR Manifest Parsing")
    func testJARParsing() throws {
        let tmpDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let tmp = tmpDir.appendingPathComponent("TestGame.jar")

        // Mock JAR containing manifest pattern
        let manifest = """
        Manifest-Version: 1.0
        MIDlet-Name: Retro Racing
        MIDlet-Version: 1.4.2
        MIDlet-Vendor: Nokia Games Studio
        MicroEdition-Profile: MIDP-2.1
        """
        var jarData = "PK\u{03}\u{04}".data(using: .utf8)!
        jarData.append("META-INF/MANIFEST.MF".data(using: .utf8)!)
        jarData.append(manifest.data(using: .utf8)!)
        try jarData.write(to: tmp)

        let parsed = SymbianSISParser.parse(url: tmp)
        #expect(parsed.packageType == .jar)
        #expect(parsed.appName == "Retro Racing")
        #expect(parsed.version == "1.4.2")
        #expect(parsed.appVendor == "Nokia Games Studio")
    }

    // MARK: - 3. ID3 Audio Parser Tests

    @Test("SymbianID3Parser ID3v2 Tag Extraction")
    func testID3v2Parsing() throws {
        let tmpDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let tmp = tmpDir.appendingPathComponent("test_track.mp3")

        // Mock MP3 file with an ID3v2.3 tag
        let fileData = buildID3v2File(frames: [
            ("TIT2", "Over the Hills and Far Away"),
            ("TPE1", "Nightwish"),
            ("TALB", "Century Child"),
            ("TYER", "2002"),
            ("TRCK", "5/10")
        ])
        try fileData.write(to: tmp)

        let track = SymbianID3Parser.parse(url: tmp)
        #expect(track.title == "Over the Hills and Far Away")
        #expect(track.artist == "Nightwish")
        #expect(track.album == "Century Child")
        #expect(track.year == "2002")
        #expect(track.trackNumber == 5)
        #expect(track.relativeDevicePath.contains("Nightwish/Century Child"))
        #expect(track.relativeDevicePath.hasSuffix(".mp3"))
    }

    @Test("SymbianID3Parser ID3v2.2 6-byte Frame Headers Parse Safely")
    func testID3v22Parsing() throws {
        let tmpDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let tmp = tmpDir.appendingPathComponent("v22_track.mp3")

        // ID3v2.2 uses 3-char frame IDs (TT2/TP1) with 6-byte frame headers
        let fileData = buildID3v2File(frames: [
            ("TT2", "V22 Title"),
            ("TP1", "V22 Artist")
        ], version: 2, payloadSize: 256)
        try fileData.write(to: tmp)

        let track = SymbianID3Parser.parse(url: tmp)
        #expect(track.title == "V22 Title")
        #expect(track.artist == "V22 Artist")
    }

    @Test("ID3 Parser Preserves .m4a Extension and Guards ID3v1.0 Zero Track Byte")
    func testExtensionPreservationAndID3v1Guard() throws {
        let tmpDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // .m4a file with an ID3v2.3 tag → device path keeps the .m4a extension
        let m4aURL = tmpDir.appendingPathComponent("track.m4a")
        try buildID3v2File(frames: [("TIT2", "Amaranth"), ("TPE1", "Nightwish")], payloadSize: 512)
            .write(to: m4aURL)
        let m4aTrack = SymbianID3Parser.parse(url: m4aURL)
        #expect(m4aTrack.relativeDevicePath.hasSuffix(".m4a"))
        #expect(m4aTrack.relativeDevicePath.contains("Nightwish"))

        // ID3v1.0 tag (byte 125 == 0, byte 126 == 0) → trackNumber must NOT become 0
        let v1URL = tmpDir.appendingPathComponent("old.mp3")
        var v1 = Data(repeating: 0, count: 128)
        v1[0] = 0x54; v1[1] = 0x41; v1[2] = 0x47 // "TAG"
        let titleBytes = Array("Old Song".data(using: .isoLatin1)!)
        v1.replaceSubrange(3..<(3 + titleBytes.count), with: titleBytes)
        v1[125] = 0 // ID3v1.0: no track-number marker
        v1[126] = 0 // track byte 0 → must be ignored
        try v1.write(to: v1URL)
        let v1Track = SymbianID3Parser.parse(url: v1URL)
        #expect(v1Track.title == "Old Song")
        #expect(v1Track.trackNumber == 1) // default kept, never 0

        // ID3v1.1 tag with track byte 7 → trackNumber == 7
        let v11URL = tmpDir.appendingPathComponent("old11.mp3")
        var v11 = v1
        v11[126] = 7
        try v11.write(to: v11URL)
        let v11Track = SymbianID3Parser.parse(url: v11URL)
        #expect(v11Track.trackNumber == 7)
    }

    // MARK: - 4. Playlist Generator Tests

    @Test("SymbianPlaylistGenerator M3U Content and Disk Output")
    func testPlaylistGeneration() throws {
        let tracks = [
            SymbianTrack(
                title: "Amaranth",
                artist: "Nightwish",
                album: "Dark Passion Play",
                trackNumber: 1,
                duration: 235,
                relativeDevicePath: "Music/Nightwish/Dark Passion Play/01 - Amaranth.mp3"
            ),
            SymbianTrack(
                title: "Bye Bye Beautiful",
                artist: "Nightwish",
                album: "Dark Passion Play",
                trackNumber: 2,
                duration: 254,
                relativeDevicePath: "Music/Nightwish/Dark Passion Play/02 - Bye Bye Beautiful.mp3"
            )
        ]

        let content = SymbianPlaylistGenerator.generateContent(tracks: tracks, relativeToPlaylistDirectory: true)
        #expect(content.contains("#EXTM3U"))
        #expect(content.contains("#EXTINF:235,Nightwish - Amaranth"))
        #expect(content.contains("..\\Nightwish\\Dark Passion Play\\01 - Amaranth.mp3"))

        // Test writing to disk
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("symbian_disk_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let writtenURL = try SymbianPlaylistGenerator.writePlaylist(
            tracks: tracks,
            playlistName: "Nightwish_Favorites",
            deviceMountURL: tmpDir
        )
        #expect(FileManager.default.fileExists(atPath: writtenURL.path))
        #expect(writtenURL.lastPathComponent == "Nightwish_Favorites.m3u")
    }

    // MARK: - 5. Filesystem Helper & Dotfile Cleaner Tests

    @Test("SymbianFilesystemHelper Detection and AppleDouble Cleaning")
    func testFilesystemDetectionAndCleaning() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mock_symbian_vol_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Before creating Symbian signature
        #expect(!SymbianFilesystemHelper.hasSymbianSignature(at: tmpDir))

        // Create a realistic Symbian Belle mass-memory layout
        // (core dirs sys/resource/private alongside installs + user dirs)
        for d in ["sys", "private", "resource", "installs", "Music"] {
            try FileManager.default.createDirectory(at: tmpDir.appendingPathComponent(d), withIntermediateDirectories: true)
        }

        #expect(SymbianFilesystemHelper.hasSymbianSignature(at: tmpDir))

        // Device detection
        let detected = SymbianFilesystemHelper.detectDevice(at: tmpDir, volumeName: "NOKIA")
        #expect(detected != nil)
        #expect(detected?.driveLetter == "E:")
        #expect(detected?.isInternalMassMemory == true)

        // Create corrupting macOS AppleDouble files
        let dotfile1 = tmpDir.appendingPathComponent("Music/._song.mp3")
        let dotfile2 = tmpDir.appendingPathComponent(".DS_Store")
        try "dotfile detritus".write(to: dotfile1, atomically: true, encoding: .utf8)
        try "ds store".write(to: dotfile2, atomically: true, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: dotfile1.path))
        #expect(FileManager.default.fileExists(atPath: dotfile2.path))

        let cleaned = SymbianFilesystemHelper.cleanAppleDoubleFiles(at: tmpDir)
        #expect(cleaned == 2)
        #expect(!FileManager.default.fileExists(atPath: dotfile1.path))
        #expect(!FileManager.default.fileExists(atPath: dotfile2.path))
    }

    @Test("hasSymbianSignature Rejects macOS and Generic Non-Symbian Volumes")
    func testNonSymbianVolumesRejected() throws {
        let fm = FileManager.default

        // Single generic `private` folder (typical of macOS data volumes) — must NOT match
        let privateOnly = try makeTempDir()
        defer { try? fm.removeItem(at: privateOnly) }
        try fm.createDirectory(at: privateOnly.appendingPathComponent("private"), withIntermediateDirectories: true)
        #expect(!SymbianFilesystemHelper.hasSymbianSignature(at: privateOnly))

        // Single generic `system` folder — must NOT match
        let systemOnly = try makeTempDir()
        defer { try? fm.removeItem(at: systemOnly) }
        try fm.createDirectory(at: systemOnly.appendingPathComponent("system"), withIntermediateDirectories: true)
        #expect(!SymbianFilesystemHelper.hasSymbianSignature(at: systemOnly))

        // macOS-like volume: System/Library + Applications + Users + private/var/db
        let macVol = try makeTempDir()
        defer { try? fm.removeItem(at: macVol) }
        for d in ["System/Library", "Applications", "Users", "private/var/db"] {
            try fm.createDirectory(at: macVol.appendingPathComponent(d), withIntermediateDirectories: true)
        }
        #expect(!SymbianFilesystemHelper.hasSymbianSignature(at: macVol))
        #expect(SymbianFilesystemHelper.detectDevice(at: macVol, volumeName: "Macintosh HD") == nil)

        // Sneaky volume: looks Symbian-ish (private + installs + Music) but carries System/Library
        let sneaky = try makeTempDir()
        defer { try? fm.removeItem(at: sneaky) }
        for d in ["private", "installs", "Music", "System/Library"] {
            try fm.createDirectory(at: sneaky.appendingPathComponent(d), withIntermediateDirectories: true)
        }
        #expect(!SymbianFilesystemHelper.hasSymbianSignature(at: sneaky))

        // Realistic Symbian Belle mass-memory layout — must match
        let symbianVol = try makeTempDir()
        defer { try? fm.removeItem(at: symbianVol) }
        for d in ["sys/bin", "resource/apps", "private/10202be9", "installs", "cities", "Music"] {
            try fm.createDirectory(at: symbianVol.appendingPathComponent(d), withIntermediateDirectories: true)
        }
        #expect(SymbianFilesystemHelper.hasSymbianSignature(at: symbianVol))
    }

    @Test("cleanAppleDoubleFiles Skips Symlinks (lstat) and Enforces Max Depth")
    func testCleanSkipsSymlinksAndDepth() throws {
        let fm = FileManager.default
        let root = try makeTempDir()
        let outside = try makeTempDir()
        defer {
            try? fm.removeItem(at: root)
            try? fm.removeItem(at: outside)
        }

        // Real AppleDouble file inside the cleaned tree → removed
        let dot = root.appendingPathComponent("._song.mp3")
        try "x".write(to: dot, atomically: true, encoding: .utf8)

        // Victim file outside the cleaned tree
        let victim = outside.appendingPathComponent("._victim.mp3")
        try "x".write(to: victim, atomically: true, encoding: .utf8)

        // Symlink named like an AppleDouble file pointing at the victim — must NOT be unlinked or followed
        let link = root.appendingPathComponent("._link.mp3")
        try fm.createSymbolicLink(at: link, withDestinationURL: victim)

        // Symlink to a directory outside the tree — must NOT be traversed
        let dirLink = root.appendingPathComponent("linked_dir")
        try fm.createSymbolicLink(at: dirLink, withDestinationURL: outside)

        // Deep chain beyond the max recursion depth (32) — dotfile at the bottom must survive
        var deep = root
        for i in 0..<40 {
            deep = deep.appendingPathComponent("d\(i)")
        }
        try fm.createDirectory(at: deep, withIntermediateDirectories: true)
        let deepDot = deep.appendingPathComponent("._deep.mp3")
        try "x".write(to: deepDot, atomically: true, encoding: .utf8)

        let cleaned = SymbianFilesystemHelper.cleanAppleDoubleFiles(at: root)
        #expect(cleaned == 1)
        #expect(!fm.fileExists(atPath: dot.path))
        #expect(fm.fileExists(atPath: victim.path)) // untouched — symlink was not followed
        #expect(try fm.destinationOfSymbolicLink(atPath: link.path) == victim.path) // symlink itself kept
        #expect(fm.fileExists(atPath: deepDot.path)) // beyond max depth — not cleaned
    }

    // MARK: - 6. Registry & Opt-in Behavior

    @Test("Symbian Plugin Registry Specification (Disabled by Default)")
    func testPluginRegistryOptIn() {
        let plugin = DMSPluginRegistry.standardPlugins.first(where: { $0.id == "symbian-belle-sync" })
        #expect(plugin != nil)
        #expect(plugin?.name == "Nokia Belle USB Sync")
        #expect(plugin?.isEnabled == false)
        #expect(plugin?.isInstalled == false)
        #expect(plugin?.tags.contains("nokia") == true)
        #expect(plugin?.tags.contains("c7") == true)
        #expect(plugin?.tags.contains("belle") == true)
    }

    // MARK: - 7. IPC Command Parsing Tests

    @Test("Symbian IPC Command Parsing CLI and URL")
    func testSymbianIPCParsing() {
        let cmd1 = IPCCommand.parseCLI(args: ["symbian", "status"])
        if case .symbian(let action, _, _) = cmd1 {
            #expect(action == "status")
        } else {
            Issue.record("Expected .symbian command")
        }

        let cmd2 = IPCCommand.parseCLI(args: ["symbian", "install", "/Users/jonas/App.sisx"])
        if case .symbian(let action, let path, _) = cmd2 {
            #expect(action == "install")
            #expect(path == "/Users/jonas/App.sisx")
        } else {
            Issue.record("Expected .symbian install command")
        }

        let urlCmd = IPCCommand.parse(url: URL(string: "dms://symbian/open")!)
        if case .symbian(let action, _, _) = urlCmd {
            #expect(action == "open")
        } else {
            Issue.record("Expected .symbian open command")
        }
    }

    // MARK: - 8. SymbianClient & FAT32 Sanitization Tests

    @Test("FAT32 Path Component Sanitization")
    func testFAT32Sanitization() {
        let clean1 = SymbianID3Parser.sanitizeFATPathComponent("Science/Visions")
        #expect(clean1 == "Science_Visions")

        let clean2 = SymbianID3Parser.sanitizeFATPathComponent("What Ever Happened To All The Fun: In The World?")
        #expect(clean2 == "What Ever Happened To All The Fun_ In The World_")

        let clean3 = SymbianID3Parser.sanitizeFATPathComponent("Track * <1> > | \"Quotes\"")
        #expect(!clean3.contains("*"))
        #expect(!clean3.contains("<"))
        #expect(!clean3.contains(">"))
        #expect(!clean3.contains("|"))
        #expect(!clean3.contains("\""))
    }

    @Test("sanitizeFATPathComponent Rejects Traversal, Trailing Dots, and Reserved DOS Names")
    func testSanitizeFATPathComponentHardening() {
        // Path traversal components
        #expect(SymbianID3Parser.sanitizeFATPathComponent(".") == "Unknown")
        #expect(SymbianID3Parser.sanitizeFATPathComponent("..") == "Unknown")
        #expect(SymbianID3Parser.sanitizeFATPathComponent("...") == "Unknown")

        // Trailing dots and spaces are invalid on FAT32
        #expect(SymbianID3Parser.sanitizeFATPathComponent("Song...") == "Song")
        #expect(SymbianID3Parser.sanitizeFATPathComponent("Song. ") == "Song")

        // Reserved DOS device names (case-insensitive, with or without extension)
        #expect(SymbianID3Parser.sanitizeFATPathComponent("CON") == "Unknown")
        #expect(SymbianID3Parser.sanitizeFATPathComponent("con") == "Unknown")
        #expect(SymbianID3Parser.sanitizeFATPathComponent("Nul") == "Unknown")
        #expect(SymbianID3Parser.sanitizeFATPathComponent("aux.mp3") == "Unknown")
        #expect(SymbianID3Parser.sanitizeFATPathComponent("COM1") == "Unknown")
        #expect(SymbianID3Parser.sanitizeFATPathComponent("lpt9") == "Unknown")

        // Lookalikes that are NOT reserved stay intact
        #expect(SymbianID3Parser.sanitizeFATPathComponent("Console") == "Console")
        #expect(SymbianID3Parser.sanitizeFATPathComponent("COM10") == "COM10")

        // Audio extension normalization
        #expect(SymbianID3Parser.normalizedAudioExtension("M4A") == "m4a")
        #expect(SymbianID3Parser.normalizedAudioExtension("WAV") == "wav")
        #expect(SymbianID3Parser.normalizedAudioExtension("") == "mp3")
        #expect(SymbianID3Parser.normalizedAudioExtension("exe") == "mp3")
    }

    @Test("SymbianClient Resolution and Error Boundary")
    func testSymbianClient() {
        let client = SymbianClient(customExecutablePath: "/nonexistent/dms-symbian-tool")
        #expect(client.resolveExecutablePath() == nil)

        let launchRes = client.launchCompanion()
        if case .failure(let err) = launchRes {
            #expect(err.description.contains("not found"))
        } else {
            Issue.record("Expected failure for nonexistent executable")
        }

        let actionRes = client.runAction("status")
        if case .failure(let err) = actionRes {
            #expect(err.description.contains("not found"))
        } else {
            Issue.record("Expected failure for nonexistent executable")
        }
    }
}
