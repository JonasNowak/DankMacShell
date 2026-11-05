import Foundation
import AppKit
import Combine
import DMSCore

/// Dedicated service managing USB detection, MP3 syncing, and SIS/SISX app installation for Symbian Belle devices.
/// Runs inside the standalone `dms-symbian` companion process.
@MainActor
public final class SymbianSyncService: ObservableObject {
    public static let shared = SymbianSyncService()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var connectedDevices: [SymbianDevice] = []
    @Published public var activeDevice: SymbianDevice? = nil {
        didSet {
            if let dev = activeDevice {
                refreshActiveDeviceData(dev)
            }
        }
    }

    @Published public private(set) var localTracks: [SymbianTrack] = []
    @Published public private(set) var deviceTracks: [SymbianTrack] = []
    @Published public private(set) var stagedPackages: [SymbianAppPackage] = []
    @Published public private(set) var storageBreakdown: SymbianStorageBreakdown? = nil

    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var syncProgress: Double = 0.0
    @Published public private(set) var syncStatusMessage: String = ""
    @Published public private(set) var isScanningLocal: Bool = false
    @Published public var userToastMessage: String? = nil

    private var mountObserver: Any?
    private var unmountObserver: Any?

    private init() {}

    // MARK: - Lifecycle

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        let center = NSWorkspace.shared.notificationCenter
        mountObserver = center.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor in
                self?.handleVolumeMounted(notif)
            }
        }

        unmountObserver = center.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor in
                self?.handleVolumeUnmounted(notif)
            }
        }

        scanMountedVolumes()
        scanLocalMusic()
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false

        if let mo = mountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(mo)
            mountObserver = nil
        }
        if let uo = unmountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(uo)
            unmountObserver = nil
        }

        connectedDevices.removeAll()
        activeDevice = nil
        localTracks.removeAll()
        deviceTracks.removeAll()
        stagedPackages.removeAll()
        storageBreakdown = nil
    }

    // MARK: - Volume & Device Detection

    public func scanMountedVolumes() {
        var detected: [SymbianDevice] = []
        let fm = FileManager.default

        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsInternalKey]
        if let volumes = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) {
            for volURL in volumes {
                if volURL.path == "/" || volURL.path == "/System/Volumes/Data" { continue }
                let name = (try? volURL.resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? volURL.lastPathComponent
                if let dev = SymbianFilesystemHelper.detectDevice(at: volURL, volumeName: name) {
                    detected.append(dev)
                }
            }
        }

        self.connectedDevices = detected
        if activeDevice == nil || !detected.contains(where: { $0.id == activeDevice?.id }) {
            self.activeDevice = detected.first
        }
    }

    private func handleVolumeMounted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let url = userInfo[NSWorkspace.volumeURLUserInfoKey] as? URL else {
            scanMountedVolumes()
            return
        }

        let name = (try? url.resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? url.lastPathComponent
        if let dev = SymbianFilesystemHelper.detectDevice(at: url, volumeName: name) {
            if !connectedDevices.contains(where: { $0.id == dev.id }) {
                connectedDevices.append(dev)
                if activeDevice == nil {
                    activeDevice = dev
                }
                showFeedback("Nokia C7 connected (\(dev.driveLetter) \(dev.volumeName))")
            }
        }
    }

    private func handleVolumeUnmounted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let url = userInfo[NSWorkspace.volumeURLUserInfoKey] as? URL else {
            scanMountedVolumes()
            return
        }

        let path = url.path
        if let removed = connectedDevices.first(where: { $0.mountPath == path }) {
            connectedDevices.removeAll(where: { $0.id == removed.id })
            if activeDevice?.id == removed.id {
                activeDevice = connectedDevices.first
            }
            showFeedback("Nokia C7 disconnected")
        }
    }

    // MARK: - Library Scans

    public func refreshActiveDeviceData(_ device: SymbianDevice) {
        Task.detached(priority: .userInitiated) {
            let breakdown = SymbianFilesystemHelper.calculateStorageBreakdown(for: device)
            let dTracks = Self.scanDirectoryForAudioStatic(url: device.musicURL)
            let dApps = Self.scanDirectoryForPackagesStatic(url: device.installsURL)

            await MainActor.run {
                self.storageBreakdown = breakdown
                self.deviceTracks = dTracks
                self.stagedPackages = dApps
                self.recomputeTrackSyncStatus()
            }
        }
    }

    public func scanLocalMusic(from folderURL: URL? = nil) {
        isScanningLocal = true
        let target = folderURL ?? FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!

        Task.detached(priority: .userInitiated) {
            let scanned = Self.scanDirectoryForAudioStatic(url: target)
            await MainActor.run {
                self.localTracks = scanned
                self.isScanningLocal = false
                self.recomputeTrackSyncStatus()
            }
        }
    }

    private func recomputeTrackSyncStatus() {
        let existingTitles = Set(deviceTracks.map { "\($0.artist.lowercased()) - \($0.title.lowercased())" })
        var updated = localTracks
        for idx in updated.indices {
            let key = "\(updated[idx].artist.lowercased()) - \(updated[idx].title.lowercased())"
            updated[idx].isSyncedToDevice = existingTitles.contains(key)
        }
        self.localTracks = updated
    }

    private nonisolated static func scanDirectoryForAudioStatic(url: URL) -> [SymbianTrack] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return [] }

        let allowed = Set(["mp3", "m4a", "aac", "wav", "wma"])
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [SymbianTrack] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if allowed.contains(ext) {
                let track = SymbianID3Parser.parse(url: fileURL)
                results.append(track)
            }
            if results.count >= 2000 { break }
        }
        return results
    }

    private nonisolated static func scanDirectoryForPackagesStatic(url: URL) -> [SymbianAppPackage] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return [] }

        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        var results: [SymbianAppPackage] = []
        for fileURL in contents {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "sisx" || ext == "sis" || ext == "jar" || ext == "wgz" {
                var pkg = SymbianSISParser.parse(url: fileURL)
                pkg.isStagedOnDevice = true
                results.append(pkg)
            }
        }
        return results
    }

    // MARK: - Actions: Music Sync (Fully Asynchronous & Non-Blocking)

    public func syncTracks(
        tracks: [SymbianTrack],
        autoOrganize: Bool = true,
        generatePlaylist: Bool = true,
        cleanDotfiles: Bool = true
    ) async -> Int {
        guard let device = activeDevice else { return 0 }
        guard !tracks.isEmpty else { return 0 }

        isSyncing = true
        syncProgress = 0.0
        syncStatusMessage = "Preparing Symbian Belle Music folders..."

        let mountURL = URL(fileURLWithPath: device.mountPath)
        try? SymbianFilesystemHelper.ensureDirectories(at: mountURL)

        let total = tracks.count
        let capturedTracks = tracks
        let capturedDevice = device

        // Run the heavy file copy operations strictly on a detached background task
        let successCount = await Task.detached(priority: .utility) { () -> Int in
            let fm = FileManager.default
            var successes = 0

            for (index, track) in capturedTracks.enumerated() {
                await MainActor.run {
                    SymbianSyncService.shared.syncStatusMessage = "Syncing (\(index + 1)/\(total)): \(track.artist) - \(track.title)"
                    SymbianSyncService.shared.syncProgress = Double(index) / Double(total)
                }

                let destURL: URL
                if autoOrganize {
                    // Safe FAT path components
                    let safeArtist = SymbianID3Parser.sanitizeFATPathComponent(track.artist)
                    let safeAlbum = SymbianID3Parser.sanitizeFATPathComponent(track.album)
                    let safeTitle = SymbianID3Parser.sanitizeFATPathComponent(track.title)
                    let trackRel = "Music/\(safeArtist)/\(safeAlbum)/\(String(format: "%02d", track.trackNumber)) - \(safeTitle).mp3"
                    destURL = mountURL.appendingPathComponent(trackRel)
                } else {
                    let fileName = (track.filePath as NSString).lastPathComponent
                    let safeFileName = SymbianID3Parser.sanitizeFATPathComponent((fileName as NSString).deletingPathExtension) + ".\((fileName as NSString).pathExtension)"
                    destURL = capturedDevice.musicURL.appendingPathComponent(safeFileName)
                }

                do {
                    let dir = destURL.deletingLastPathComponent()
                    if !fm.fileExists(atPath: dir.path) {
                        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                    }

                    if fm.fileExists(atPath: destURL.path) {
                        try? fm.removeItem(at: destURL)
                    }

                    let srcURL = URL(fileURLWithPath: track.filePath)
                    try fm.copyItem(at: srcURL, to: destURL)
                    successes += 1
                } catch {
                    print("Failed to sync track \(track.title): \(error.localizedDescription)")
                }

                await Task.yield()
            }

            if generatePlaylist {
                await MainActor.run {
                    SymbianSyncService.shared.syncStatusMessage = "Generating Nokia Belle M3U Playlist..."
                }
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateStr = formatter.string(from: Date())
                _ = try? SymbianPlaylistGenerator.writePlaylist(
                    tracks: capturedTracks,
                    playlistName: "Sync_\(dateStr)",
                    deviceMountURL: mountURL
                )
            }

            if cleanDotfiles {
                await MainActor.run {
                    SymbianSyncService.shared.syncStatusMessage = "Cleaning macOS AppleDouble dotfiles..."
                }
                SymbianFilesystemHelper.cleanAppleDoubleFiles(at: capturedDevice.musicURL)
            }

            return successes
        }.value

        syncProgress = 1.0
        syncStatusMessage = "Completed! Synced \(successCount) tracks."
        try? await Task.sleep(nanoseconds: 500_000_000)

        isSyncing = false
        refreshActiveDeviceData(device)
        showFeedback("Synced \(successCount) tracks to Nokia C7")
        return successCount
    }

    // MARK: - Actions: App Installation & Staging

    @discardableResult
    public func stagePackage(from sourceURL: URL) async throws -> SymbianAppPackage {
        guard let device = activeDevice else {
            throw NSError(domain: "SymbianSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "No Nokia C7 device connected"])
        }

        let mountURL = URL(fileURLWithPath: device.mountPath)
        try SymbianFilesystemHelper.ensureDirectories(at: mountURL)

        let parsed = SymbianSISParser.parse(url: sourceURL)
        let fm = FileManager.default
        let destURL = device.installsURL.appendingPathComponent(sourceURL.lastPathComponent)

        if fm.fileExists(atPath: destURL.path) {
            try? fm.removeItem(at: destURL)
        }

        try fm.copyItem(at: sourceURL, to: destURL)

        let guideURL = device.installsURL.appendingPathComponent("HOW_TO_INSTALL.txt")
        if !fm.fileExists(atPath: guideURL.path) {
            let guide = """
            ==============================================
            NOKIA BELLE APPLICATION INSTALLATION GUIDE
            ==============================================
            1. Disconnect USB cable or switch mode to Nokia Suite.
            2. On your Nokia C7, tap:
               Menu -> Applications -> Office -> File Manager
            3. Open Drive E: (Mass Memory) -> Installs
            4. Tap on the .sis / .sisx package to begin install!
            ==============================================
            """
            try? guide.write(to: guideURL, atomically: true, encoding: .utf8)
        }

        SymbianFilesystemHelper.cleanAppleDoubleFiles(at: device.installsURL)
        refreshActiveDeviceData(device)
        showFeedback("Staged \(parsed.appName) to Nokia C7 Installs")
        return parsed
    }

    public func removeStagedPackage(_ package: SymbianAppPackage) {
        guard let device = activeDevice else { return }
        let target = device.installsURL.appendingPathComponent(package.fileName)
        try? FileManager.default.removeItem(at: target)
        refreshActiveDeviceData(device)
        showFeedback("Removed \(package.fileName)")
    }

    // MARK: - Actions: Ejection & Cleaning

    public func cleanDeviceDotfiles() {
        guard let device = activeDevice else { return }
        let mountURL = URL(fileURLWithPath: device.mountPath)
        let removed = SymbianFilesystemHelper.cleanAppleDoubleFiles(at: mountURL)
        refreshActiveDeviceData(device)
        showFeedback("Cleaned \(removed) macOS dotfiles from Nokia C7")
    }

    public func ejectActiveDevice() {
        guard let device = activeDevice else { return }

        let mountURL = URL(fileURLWithPath: device.mountPath)
        SymbianFilesystemHelper.cleanAppleDoubleFiles(at: mountURL)

        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: mountURL)
            connectedDevices.removeAll(where: { $0.id == device.id })
            activeDevice = connectedDevices.first
            showFeedback("Nokia C7 safely disconnected")
        } catch {
            showFeedback("Eject failed: \(error.localizedDescription)")
        }
    }

    private func showFeedback(_ message: String) {
        self.userToastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.userToastMessage == message {
                self.userToastMessage = nil
            }
        }
    }
}
