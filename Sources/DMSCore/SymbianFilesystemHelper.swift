import Foundation
import Darwin

/// Helpers for analyzing, querying, and managing Symbian OS Belle filesystem structures.
public enum SymbianFilesystemHelper {

    /// Characteristic Symbian OS root directory names.
    public static let symbianSystemFolders = ["sys", "resource", "private", "system"]
    public static let symbianUserFolders = ["music", "installs", "images", "videos", "cities", "data", "others"]

    /// Tests if a directory contains Symbian OS markers.
    public static func hasSymbianSignature(at url: URL) -> Bool {
        let fm = FileManager.default
        let path = url.path
        if path == "/" || path == "/System/Volumes/Data" || fm.fileExists(atPath: url.appendingPathComponent("System/Library").path) {
            return false
        }
        guard let contents = try? fm.contentsOfDirectory(atPath: url.path) else { return false }
        let lowercased = contents.map { $0.lowercased() }

        var systemMatches = 0
        for folder in symbianSystemFolders {
            if lowercased.contains(folder) {
                systemMatches += 1
            }
        }

        var userMatches = 0
        for folder in symbianUserFolders {
            if lowercased.contains(folder) {
                userMatches += 1
            }
        }

        // Presence of at least 1 system folder (like 'private' or 'sys') or 2 characteristic folders
        return systemMatches >= 1 || (systemMatches + userMatches >= 2)
    }

    /// Evaluates if a volume likely belongs to a Nokia C7 or Symbian Belle phone.
    public static func detectDevice(at mountURL: URL, volumeName: String, bsdName: String? = nil) -> SymbianDevice? {
        let path = mountURL.path
        if path == "/" || path == "/System/Volumes/Data" {
            return nil
        }
        let fm = FileManager.default
        if fm.fileExists(atPath: mountURL.appendingPathComponent("System/Library").path) {
            return nil
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

    /// Removes macOS hidden AppleDouble (`._*`) and `.DS_Store` files using POSIX direct filesystem traversal.
    @discardableResult
    public static func cleanAppleDoubleFiles(at rootURL: URL) -> Int {
        var count = 0
        cleanRecursive(path: rootURL.path, count: &count)
        return count
    }

    private static func cleanRecursive(path: String, count: inout Int) {
        guard let dir = opendir(path) else { return }
        defer { closedir(dir) }

        while let entry = readdir(dir) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { ptr in
                String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
            if name == "." || name == ".." { continue }

            let fullPath = (path as NSString).appendingPathComponent(name)

            var isDir = (entry.pointee.d_type == DT_DIR)
            if entry.pointee.d_type == DT_UNKNOWN {
                var st = stat()
                if stat(fullPath, &st) == 0 {
                    isDir = (st.st_mode & S_IFMT) == S_IFDIR
                }
            }

            if !isDir {
                if name.hasPrefix("._") || name == ".DS_Store" {
                    if unlink(fullPath) == 0 {
                        count += 1
                    }
                }
            } else {
                // Don't recurse into .fseventsd or .Spotlight-V100 or .Trashes
                if name != ".Spotlight-V100" && name != ".fseventsd" && name != ".Trashes" {
                    cleanRecursive(path: fullPath, count: &count)
                }
            }
        }
    }
}
