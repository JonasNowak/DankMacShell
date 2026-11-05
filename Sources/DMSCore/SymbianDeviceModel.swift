import Foundation

/// Represents a Symbian package type (SISX for Symbian^3/Anna/Belle, legacy SIS, Java MIDP JAR, or WRT widget WGZ).
public enum SymbianPackageType: String, Sendable, Codable, CaseIterable {
    case sisx = "SISX"
    case sis = "SIS"
    case jar = "JAR"
    case wgz = "WGZ"

    public var title: String {
        switch self {
        case .sisx: return "Symbian Belle SISX"
        case .sis: return "Legacy SIS"
        case .jar: return "Java ME MIDlet"
        case .wgz: return "Web Runtime Widget"
        }
    }

    public var icon: String {
        switch self {
        case .sisx: return "app.badge.checkmark"
        case .sis: return "cube.box"
        case .jar: return "cup.and.saucer"
        case .wgz: return "globe"
        }
    }
}

/// Metadata and state of an application package intended for or staged on the Symbian Belle device.
public struct SymbianAppPackage: Identifiable, Sendable, Codable, Equatable {
    public var id: String
    public var fileName: String
    public var appName: String
    public var appVendor: String
    public var version: String
    public var uid: String // e.g. "0x2002A123"
    public var packageType: SymbianPackageType
    public var targetPlatform: String
    public var fileSize: Int64
    public var filePath: String
    public var isStagedOnDevice: Bool
    public var dateAdded: Date

    public init(
        id: String = UUID().uuidString,
        fileName: String,
        appName: String,
        appVendor: String = "Symbian Developer",
        version: String = "1.00(0)",
        uid: String = "0x20000000",
        packageType: SymbianPackageType = .sisx,
        targetPlatform: String = "Symbian Belle / Symbian^3",
        fileSize: Int64 = 0,
        filePath: String = "",
        isStagedOnDevice: Bool = false,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.appName = appName
        self.appVendor = appVendor
        self.version = version
        self.uid = uid
        self.packageType = packageType
        self.targetPlatform = targetPlatform
        self.fileSize = fileSize
        self.filePath = filePath
        self.isStagedOnDevice = isStagedOnDevice
        self.dateAdded = dateAdded
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

/// Represents an audio track (MP3, AAC, M4A, etc.) for Symbian Belle music synchronization.
public struct SymbianTrack: Identifiable, Sendable, Codable, Equatable {
    public var id: String
    public var title: String
    public var artist: String
    public var album: String
    public var year: String
    public var genre: String
    public var trackNumber: Int
    public var duration: TimeInterval
    public var fileSize: Int64
    public var bitrate: Int // kbps
    public var filePath: String
    public var relativeDevicePath: String // e.g. "Music/Nightwish/Imaginaerum/01 - Taikatalvi.mp3"
    public var isSyncedToDevice: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String = "Unknown Artist",
        album: String = "Unknown Album",
        year: String = "",
        genre: String = "",
        trackNumber: Int = 1,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        bitrate: Int = 320,
        filePath: String = "",
        relativeDevicePath: String = "",
        isSyncedToDevice: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.year = year
        self.genre = genre
        self.trackNumber = trackNumber
        self.duration = duration
        self.fileSize = fileSize
        self.bitrate = bitrate
        self.filePath = filePath
        let safeArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown Artist" : artist
        let safeAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown Album" : album
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Track" : title
        self.relativeDevicePath = relativeDevicePath.isEmpty ? "Music/\(safeArtist)/\(safeAlbum)/\(safeTitle).mp3" : relativeDevicePath
        self.isSyncedToDevice = isSyncedToDevice
    }

    public var formattedDuration: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

/// Storage breakdown of a Symbian Belle storage volume.
public struct SymbianStorageBreakdown: Sendable, Codable, Equatable {
    public var musicBytes: Int64
    public var appsBytes: Int64
    public var mediaBytes: Int64
    public var systemBytes: Int64
    public var otherBytes: Int64
    public var freeBytes: Int64
    public var totalBytes: Int64

    public init(
        musicBytes: Int64 = 0,
        appsBytes: Int64 = 0,
        mediaBytes: Int64 = 0,
        systemBytes: Int64 = 0,
        otherBytes: Int64 = 0,
        freeBytes: Int64 = 0,
        totalBytes: Int64 = 0
    ) {
        self.musicBytes = musicBytes
        self.appsBytes = appsBytes
        self.mediaBytes = mediaBytes
        self.systemBytes = systemBytes
        self.otherBytes = otherBytes
        self.freeBytes = freeBytes
        self.totalBytes = totalBytes
    }

    public var usedBytes: Int64 {
        max(0, totalBytes - freeBytes)
    }

    public var usedRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

/// Represents a detected Symbian device / volume (e.g. Nokia C7 Mass Memory E: or MicroSD F:).
public struct SymbianDevice: Identifiable, Sendable, Codable, Equatable {
    public var id: String
    public var name: String // "Nokia C7-00"
    public var modelName: String // "C7-00"
    public var volumeName: String // "NOKIA", "Mass memory"
    public var mountPath: String // "/Volumes/NOKIA"
    public var driveLetter: String // "E:" or "F:"
    public var isInternalMassMemory: Bool
    public var isRemovableCard: Bool
    public var totalBytes: Int64
    public var freeBytes: Int64
    public var osVersion: String // "Nokia Belle (Symbian^3)"
    public var hasSymbianFileSystem: Bool
    public var bsdName: String?

    public init(
        id: String,
        name: String = "Nokia C7-00",
        modelName: String = "C7-00",
        volumeName: String = "NOKIA",
        mountPath: String,
        driveLetter: String = "E:",
        isInternalMassMemory: Bool = true,
        isRemovableCard: Bool = false,
        totalBytes: Int64 = 8_000_000_000,
        freeBytes: Int64 = 4_000_000_000,
        osVersion: String = "Nokia Belle (Symbian^3)",
        hasSymbianFileSystem: Bool = true,
        bsdName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.modelName = modelName
        self.volumeName = volumeName
        self.mountPath = mountPath
        self.driveLetter = driveLetter
        self.isInternalMassMemory = isInternalMassMemory
        self.isRemovableCard = isRemovableCard
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.osVersion = osVersion
        self.hasSymbianFileSystem = hasSymbianFileSystem
        self.bsdName = bsdName
    }

    public var usedBytes: Int64 {
        max(0, totalBytes - freeBytes)
    }

    public var formattedTotalSpace: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    public var formattedFreeSpace: String {
        ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }

    public var formattedUsedSpace: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }

    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    public var musicURL: URL {
        URL(fileURLWithPath: mountPath).appendingPathComponent("Music")
    }

    public var installsURL: URL {
        URL(fileURLWithPath: mountPath).appendingPathComponent("Installs")
    }

    public var imagesURL: URL {
        URL(fileURLWithPath: mountPath).appendingPathComponent("Images")
    }

    public var videosURL: URL {
        URL(fileURLWithPath: mountPath).appendingPathComponent("Videos")
    }
}
