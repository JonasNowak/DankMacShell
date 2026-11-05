import Testing
import Foundation
@testable import DMSCore

@Suite("Symbian Belle USB Sync Core Engine Tests")
struct SymbianCoreTests {

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
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TestApp_v2.0_Belle.sisx")
        defer { try? FileManager.default.removeItem(at: tmp) }

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
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TestGame.jar")
        defer { try? FileManager.default.removeItem(at: tmp) }

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
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_track.mp3")
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Construct mock MP3 file with ID3v2.3 tag
        var tagBody = Data()

        // Helper to encode an ID3v2.3 frame
        func appendFrame(id: String, text: String) {
            guard let idData = id.data(using: .ascii), idData.count == 4 else { return }
            tagBody.append(idData)

            var textData = Data([3]) // UTF-8 encoding flag
            textData.append(text.data(using: .utf8)!)

            let size = UInt32(textData.count).bigEndian
            tagBody.append(Data(bytes: [size], count: 4))
            tagBody.append(Data([0, 0])) // flags
            tagBody.append(textData)
        }

        appendFrame(id: "TIT2", text: "Over the Hills and Far Away")
        appendFrame(id: "TPE1", text: "Nightwish")
        appendFrame(id: "TALB", text: "Century Child")
        appendFrame(id: "TYER", text: "2002")
        appendFrame(id: "TRCK", text: "5/10")

        // ID3 header
        var fileData = Data([0x49, 0x44, 0x33, 0x03, 0x00, 0x00]) // ID3v2.3
        let tagSize = tagBody.count
        let b0 = UInt8((tagSize >> 21) & 0x7F)
        let b1 = UInt8((tagSize >> 14) & 0x7F)
        let b2 = UInt8((tagSize >> 7) & 0x7F)
        let b3 = UInt8(tagSize & 0x7F)
        fileData.append(contentsOf: [b0, b1, b2, b3])
        fileData.append(tagBody)
        fileData.append(Data(repeating: 0xFF, count: 1024)) // simulated audio payload

        try fileData.write(to: tmp)

        let track = SymbianID3Parser.parse(url: tmp)
        #expect(track.title == "Over the Hills and Far Away")
        #expect(track.artist == "Nightwish")
        #expect(track.album == "Century Child")
        #expect(track.year == "2002")
        #expect(track.trackNumber == 5)
        #expect(track.relativeDevicePath.contains("Nightwish/Century Child"))
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

        // Create characteristic Symbian directories
        try FileManager.default.createDirectory(at: tmpDir.appendingPathComponent("sys"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmpDir.appendingPathComponent("private"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmpDir.appendingPathComponent("Music"), withIntermediateDirectories: true)

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
