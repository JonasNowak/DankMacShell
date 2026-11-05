import Foundation

/// Binary parser for Symbian installation packages (SIS, SISX, JAR, WGZ).
public enum SymbianSISParser {

    /// Magic UID constants for Symbian OS packages.
    public static let sisxMagicUID1: UInt32 = 0x10201A7A  // Symbian OS v9.x+ (Symbian^3, Anna, Belle)
    public static let sisxMagicUID2: UInt32 = 0x10000419  // Standard SIS package descriptor
    public static let legacyMagicUID1: UInt32 = 0x10000079 // Symbian OS v6/7/8 (S60v1/v2)
    public static let legacyMagicUID1Alt: UInt32 = 0x1000006D

    /// Parses an installation package from disk and returns structured metadata.
    public static func parse(url: URL) -> SymbianAppPackage {
        let fileName = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        switch ext {
        case "sisx", "sis":
            return parseSIS(url: url, fileName: fileName, fileSize: fileSize, isSisx: ext == "sisx")
        case "jar":
            return parseJAR(url: url, fileName: fileName, fileSize: fileSize)
        case "wgz":
            return parseWGZ(url: url, fileName: fileName, fileSize: fileSize)
        default:
            return fallbackPackage(fileName: fileName, url: url, fileSize: fileSize, type: .sisx)
        }
    }

    /// Parses a SIS / SISX binary file.
    public static func parseSIS(url: URL, fileName: String, fileSize: Int64, isSisx: Bool) -> SymbianAppPackage {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]), data.count >= 16 else {
            return fallbackPackage(fileName: fileName, url: url, fileSize: fileSize, type: isSisx ? .sisx : .sis)
        }

        let uid1 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self) }
        _ = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) }
        let uid3 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 8, as: UInt32.self) }

        let formattedUID = String(format: "0x%08X", uid3)
        let isBelleNative = (uid1 == sisxMagicUID1)

        // Extract readable strings from header
        let (extractedName, extractedVendor, extractedVersion) = extractSISStrings(data: data)

        let cleanedName = !extractedName.isEmpty ? extractedName : cleanNameFromFilename(fileName)
        let cleanedVendor = !extractedVendor.isEmpty ? extractedVendor : "Symbian Developer"
        let cleanedVersion = !extractedVersion.isEmpty ? extractedVersion : extractVersionFromFilename(fileName)

        let targetPlatform = isBelleNative
            ? "Symbian Belle / Symbian^3 Native"
            : (uid1 == legacyMagicUID1 || uid1 == legacyMagicUID1Alt ? "Legacy Symbian OS (S60v2/v3)" : "Symbian Signed Package")

        return SymbianAppPackage(
            fileName: fileName,
            appName: cleanedName,
            appVendor: cleanedVendor,
            version: cleanedVersion,
            uid: formattedUID,
            packageType: isBelleNative ? .sisx : (isSisx ? .sisx : .sis),
            targetPlatform: targetPlatform,
            fileSize: fileSize,
            filePath: url.path,
            isStagedOnDevice: false,
            dateAdded: Date()
        )
    }

    /// Parses a Java ME MIDP JAR archive.
    public static func parseJAR(url: URL, fileName: String, fileSize: Int64) -> SymbianAppPackage {
        // Attempt to extract MANIFEST.MF
        var appName = cleanNameFromFilename(fileName)
        var vendor = "Java ME Vendor"
        var version = "1.0.0"

        if let manifestString = extractJarManifest(url: url) {
            let lines = manifestString.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("midlet-name:") {
                    let val = trimmed.dropFirst("midlet-name:".count).trimmingCharacters(in: .whitespaces)
                    if !val.isEmpty { appName = val }
                } else if trimmed.lowercased().hasPrefix("midlet-vendor:") {
                    let val = trimmed.dropFirst("midlet-vendor:".count).trimmingCharacters(in: .whitespaces)
                    if !val.isEmpty { vendor = val }
                } else if trimmed.lowercased().hasPrefix("midlet-version:") {
                    let val = trimmed.dropFirst("midlet-version:".count).trimmingCharacters(in: .whitespaces)
                    if !val.isEmpty { version = val }
                }
            }
        }

        return SymbianAppPackage(
            fileName: fileName,
            appName: appName,
            appVendor: vendor,
            version: version,
            uid: "0x2000Java",
            packageType: .jar,
            targetPlatform: "Java ME MIDP 2.1 (Symbian Belle Run-Time)",
            fileSize: fileSize,
            filePath: url.path,
            isStagedOnDevice: false,
            dateAdded: Date()
        )
    }

    /// Parses a Web Runtime widget (`.wgz`).
    public static func parseWGZ(url: URL, fileName: String, fileSize: Int64) -> SymbianAppPackage {
        let name = cleanNameFromFilename(fileName)
        let version = extractVersionFromFilename(fileName)

        return SymbianAppPackage(
            fileName: fileName,
            appName: name,
            appVendor: "Nokia Web Runtime",
            version: version,
            uid: "0x2000WRT1",
            packageType: .wgz,
            targetPlatform: "Nokia Belle Web Runtime (WRT)",
            fileSize: fileSize,
            filePath: url.path,
            isStagedOnDevice: false,
            dateAdded: Date()
        )
    }

    // MARK: - Private String & Manifest Extraction

    private static func extractJarManifest(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }

        // Find "META-INF/MANIFEST.MF" signature in ZIP
        let pattern = "META-INF/MANIFEST.MF".data(using: .utf8)!
        guard let range = data.range(of: pattern) else { return nil }

        // Read up to 4096 bytes around or after the manifest header
        let start = range.upperBound
        let end = min(data.count, start + 4096)
        if start < end {
            let slice = data.subdata(in: start..<end)
            if let str = String(data: slice, encoding: .utf8) ?? String(data: slice, encoding: .ascii) {
                return str
            }
        }
        return nil
    }

    private static func extractSISStrings(data: Data) -> (name: String, vendor: String, version: String) {
        var name = ""
        var vendor = ""
        let version = ""

        // Scan the first 2KB of header data for printable UTF-16LE or ASCII sequences
        let headerLimit = min(data.count, 2048)
        guard headerLimit >= 16 else { return (name, vendor, version) }
        let slice = Array(data.prefix(headerLimit))

        // Try UTF-16LE extraction: many SISX headers encode app names in 16-bit unicode
        var utf16Chars: [UInt16] = []
        var foundStrings: [String] = []

        var i = 16
        while i < headerLimit - 1 {
            let ch = UInt16(slice[i]) | (UInt16(slice[i + 1]) << 8)
            if ch >= 32 && ch < 127 {
                utf16Chars.append(ch)
            } else {
                if utf16Chars.count >= 3 {
                    let s = String(utf16CodeUnits: utf16Chars, count: utf16Chars.count)
                    foundStrings.append(s)
                }
                utf16Chars.removeAll(keepingCapacity: true)
            }
            i += 2
        }

        // Also check plain ASCII sequences
        var asciiBytes: [UInt8] = []
        var asciiStrings: [String] = []
        for byte in slice.dropFirst(16) {
            if byte >= 32 && byte <= 126 {
                asciiBytes.append(byte)
            } else {
                if asciiBytes.count >= 3 {
                    if let s = String(bytes: asciiBytes, encoding: .ascii) {
                        asciiStrings.append(s)
                    }
                }
                asciiBytes.removeAll(keepingCapacity: true)
            }
        }

        let candidates = (foundStrings + asciiStrings).filter { str in
            let lower = str.lowercased()
            return !lower.contains("symbian") && !lower.contains("nokia") && !lower.contains("cert") && !lower.contains("root")
        }

        if let first = candidates.first {
            name = first.trimmingCharacters(in: .whitespaces)
        }
        if candidates.count > 1 {
            vendor = candidates[1].trimmingCharacters(in: .whitespaces)
        }

        return (name, vendor, version)
    }

    private static func fallbackPackage(fileName: String, url: URL, fileSize: Int64, type: SymbianPackageType) -> SymbianAppPackage {
        let name = cleanNameFromFilename(fileName)
        let ver = extractVersionFromFilename(fileName)
        return SymbianAppPackage(
            fileName: fileName,
            appName: name,
            appVendor: "Symbian Belle App",
            version: ver,
            uid: "0x20000000",
            packageType: type,
            targetPlatform: "Symbian Belle / Symbian^3",
            fileSize: fileSize,
            filePath: url.path,
            isStagedOnDevice: false,
            dateAdded: Date()
        )
    }

    public static func cleanNameFromFilename(_ fileName: String) -> String {
        var base = (fileName as NSString).deletingPathExtension
        // Remove common version patterns like _v1_0, _1.2.3, etc.
        let patterns = ["_v\\d.*", "v\\d.*", "_\\d+.*", "-\\d+.*"]
        for p in patterns {
            if let regex = try? NSRegularExpression(pattern: p, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: base.utf16.count)
                base = regex.stringByReplacingMatches(in: base, range: range, withTemplate: "")
            }
        }
        let cleaned = base
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? (fileName as NSString).deletingPathExtension : cleaned
    }

    public static func extractVersionFromFilename(_ fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        if let regex = try? NSRegularExpression(pattern: "(\\d+\\.\\d+(\\.\\d+)?)") {
            let ns = base as NSString
            let match = regex.firstMatch(in: base, range: NSRange(location: 0, length: ns.length))
            if let match = match, match.range.location != NSNotFound {
                return ns.substring(with: match.range)
            }
        }
        return "1.00(0)"
    }
}
