import Foundation
import Darwin

/// Helpers for analyzing, querying, and managing Symbian OS Belle filesystem structures.
public enum SymbianFilesystemHelper {

    /// Characteristic Symbian OS root directory names.
    public static let symbianSystemFolders = ["sys", "resource", "private", "system"]
    public static let symbianUserFolders = ["music", "installs", "images", "videos", "cities", "data", "others"]

    /// macOS system / backup / user volume markers — a volume containing any of
    /// these is never a Symbian device, no matter what else it contains.
    private static let macOSVolumeMarkers = [
        "System/Library",
        "Applications",
        "Users",
        "private/var/db"
    ]

    /// Concrete Symbian-specific subdirectories — strong signature markers.
    private static let symbianConcreteSubdirs = [
        "sys/bin",
        "private/10202be9",
        "resource/apps",
        "cities/diskcache"
    ]

    /// Tests if a directory contains Symbian OS markers.
    public static func hasSymbianSignature(at url: URL) -> Bool {
        let fm = FileManager.default
        let path = url.path
        if path == "/" || path == "/System/Volumes/Data" {
            return false
        }

        // Reject macOS system / backup / user volumes outright.
        for marker in macOSVolumeMarkers {
            if fm.fileExists(atPath: url.appendingPathComponent(marker).path) {
                return false
            }
        }

        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return false }
        let lowercased = Set(contents.map { $0.lowercased() })

        // Strong marker: at least one concrete Symbian subdirectory.
        var isDir: ObjCBool = false
        for sub in symbianConcreteSubdirs {
            if fm.fileExists(atPath: url.appendingPathComponent(sub).path, isDirectory: &isDir), isDir.boolValue {
                return true
            }
        }

        // Otherwise require a realistic Symbian top-level layout: at least 3 Symbian
        // dirs, including at least one of sys/resource/private alongside at least one
        // of installs/cities/others. A single generic `private` or `system` folder
        // (common on macOS/external volumes) must never match.
        let coreDirs = ["sys", "resource", "private"]
        let companionDirs = ["installs", "cities", "others"]
        let allSymbianDirs = symbianSystemFolders + symbianUserFolders
        let total = allSymbianDirs.filter { lowercased.contains($0) }.count
        let core = coreDirs.filter { lowercased.contains($0) }.count
        let companion = companionDirs.filter { lowercased.contains($0) }.count
        return total >= 3 && core >= 1 && companion >= 1
    }

    /// Evaluates if a volume likely belongs to a Nokia C7 or Symbian Belle phone.
    public static func detectDevice(at mountURL: URL, volumeName: String, bsdName: String? = nil) -> SymbianDevice? {
        let path = mountURL.path
        if path == "/" || path == "/System/Volumes/Data" {
            return nil
        }
        let fm = FileManager.default
        // Never classify a macOS system/backup/user volume as a Symbian device.
        for marker in macOSVolumeMarkers {
            if fm.fileExists(atPath: mountURL.appendingPathComponent(marker).path) {
                return nil
            }
        }
        let hasSignature = hasSymbianSignature(at: mountURL)

        let lowerName = volumeName.lowercased()
        let nameMatch = lowerName.contains("nokia") ||
                        lowerName.contains("c7") ||
                        lowerName.contains("belle") ||
                        lowerName.contains("symbian") ||
                        lowerName.contains("mass memory") ||
                        lowerName.contains("memory card")

        // Must match either the directory signature or the volume name
        guard hasSignature || nameMatch else { return nil }

        // Determine capacity
        var totalBytes: Int64 = 8_000_000_000
        var freeBytes: Int64 = 4_000_000_000
        if let attrs = try? fm.attributesOfFileSystem(forPath: mountURL.path) {
            totalBytes = (attrs[.systemSize] as? Int64) ?? totalBytes
            freeBytes = (attrs[.systemFreeSize] as? Int64) ?? freeBytes
        }

        // Nokia C7 mass memory is internal flash (Drive E:).
        // Volumes named "card", "sd", or "microsd" correspond to the removable card slot (Drive F:).
        let isCard = lowerName.contains("card") || lowerName.contains("sd") || lowerName.contains("external")
        let isInternal = !isCard
        let driveLetter = isInternal ? "E:" : "F:"
        let modelName = lowerName.contains("c7") ? "Nokia C7-00" : "Symbian Belle Device"

        return SymbianDevice(
            id: mountURL.path,
            name: "\(modelName) (\(driveLetter))",
            modelName: "C7-00 (Belle)",
            volumeName: volumeName,
            mountPath: mountURL.path,
            driveLetter: driveLetter,
            isInternalMassMemory: isInternal,
            isRemovableCard: !isInternal,
            totalBytes: totalBytes,
            freeBytes: freeBytes,
            osVersion: "Nokia Belle (Symbian^3 FP1 / Delight)",
            hasSymbianFileSystem: hasSignature,
            bsdName: bsdName
        )
    }

    /// Prepares necessary Symbian Belle directory hierarchy on the volume if missing.
    public static func ensureDirectories(at mountURL: URL) throws {
        let fm = FileManager.default
        let dirs = ["Music", "Music/Playlists", "Installs", "Images", "Videos", "Data"]
        for d in dirs {
            let dirURL = mountURL.appendingPathComponent(d)
            if !fm.fileExists(atPath: dirURL.path) {
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
            }
        }
    }

    /// Computes storage breakdown by directory category.
    public static func calculateStorageBreakdown(for device: SymbianDevice) -> SymbianStorageBreakdown {
        let mountURL = URL(fileURLWithPath: device.mountPath)

        var musicSize: Int64 = 0
        var appsSize: Int64 = 0
        var mediaSize: Int64 = 0
        var systemSize: Int64 = 0
        var otherSize: Int64 = 0

        musicSize = calculateDirectorySize(url: mountURL.appendingPathComponent("Music"))
        appsSize = calculateDirectorySize(url: mountURL.appendingPathComponent("Installs"))

        let imagesSize = calculateDirectorySize(url: mountURL.appendingPathComponent("Images"))
        let videosSize = calculateDirectorySize(url: mountURL.appendingPathComponent("Videos"))
        mediaSize = imagesSize + videosSize

        for sysDir in symbianSystemFolders {
            systemSize += calculateDirectorySize(url: mountURL.appendingPathComponent(sysDir))
        }

        let totalUsed = device.usedBytes
        let counted = musicSize + appsSize + mediaSize + systemSize
        otherSize = max(0, totalUsed - counted)

        return SymbianStorageBreakdown(
            musicBytes: musicSize,
            appsBytes: appsSize,
            mediaBytes: mediaSize,
            systemBytes: systemSize,
            otherBytes: otherSize,
            freeBytes: device.freeBytes,
            totalBytes: device.totalBytes
        )
    }

    /// Scans a directory recursively and sums file sizes.
    public static func calculateDirectorySize(url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               vals.isDirectory != true {
                total += Int64(vals.fileSize ?? 0)
            }
        }
        return total
    }

    /// Maximum recursion depth for dotfile cleaning (guards against pathological trees).
    private static let maxCleanDepth = 32

    /// Removes macOS hidden AppleDouble (`._*`) and `.DS_Store` files using POSIX direct filesystem traversal.
    /// Uses `lstat()` and never follows symlinks, so a link can never drag the cleaner off the volume.
    @discardableResult
    public static func cleanAppleDoubleFiles(at rootURL: URL) -> Int {
        var count = 0
        cleanRecursive(path: rootURL.path, depth: 0, count: &count)
        return count
    }

    private static func cleanRecursive(path: String, depth: Int, count: inout Int) {
        guard depth <= maxCleanDepth else { return }
        guard let dir = opendir(path) else { return }
        defer { closedir(dir) }

        while let entry = readdir(dir) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { ptr in
                String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
            if name == "." || name == ".." { continue }

            let fullPath = (path as NSString).appendingPathComponent(name)

            // lstat (not stat): inspect the link itself, never its target.
            var st = stat()
            guard lstat(fullPath, &st) == 0 else { continue }
            let fileType = st.st_mode & S_IFMT

            if fileType == S_IFLNK {
                // Never follow or delete through symlinks — they may point off the volume.
                continue
            }

            if fileType == S_IFDIR {
                // Don't recurse into .fseventsd or .Spotlight-V100 or .Trashes
                if name != ".Spotlight-V100" && name != ".fseventsd" && name != ".Trashes" {
                    cleanRecursive(path: fullPath, depth: depth + 1, count: &count)
                }
            } else {
                if name.hasPrefix("._") || name == ".DS_Store" {
                    if unlink(fullPath) == 0 {
                        count += 1
                    }
                }
            }
        }
    }
}
