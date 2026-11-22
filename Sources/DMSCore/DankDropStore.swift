import Foundation

/// A single item on the DankDrop file-drop shelf: a dropped file/URL or a text payload.
public struct DankDropItem: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var urlString: String?
    public var title: String
    public var subtitle: String
    public var textPayload: String?
    public var isFile: Bool
    public var fileSizeBytes: Int64?
    public var sfSymbol: String
    public var addedAt: Date

    public init(
        id: UUID = UUID(),
        urlString: String? = nil,
        title: String,
        subtitle: String = "",
        textPayload: String? = nil,
        isFile: Bool,
        fileSizeBytes: Int64? = nil,
        sfSymbol: String,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.subtitle = subtitle
        self.textPayload = textPayload
        self.isFile = isFile
        self.fileSizeBytes = fileSizeBytes
        self.sfSymbol = sfSymbol
        self.addedAt = addedAt
    }

    /// Human-readable file size (e.g. "1.4 MB") when a size is known.
    public var formattedFileSize: String? {
        guard let bytes = fileSizeBytes, bytes >= 0 else { return nil }
        return DankDropStore.formatByteCount(bytes)
    }
}

/// Pure-logic, UI-free shelf model for the Dynamic Island file-drop target ("DankDrop").
/// Most-recent item sits at the front; duplicates (same `urlString` / `textPayload`)
/// are replaced and promoted instead of duplicated.
public struct DankDropStore: Sendable, Codable, Equatable {
    public var items: [DankDropItem]
    public var maxItems: Int

    public init(items: [DankDropItem] = [], maxItems: Int = 20) {
        self.items = items
        self.maxItems = max(1, maxItems)
    }

    /// Adds a dropped file or link URL to the front of the shelf, deduplicating by `urlString`.
    public mutating func addFile(url: URL, fileSizeBytes: Int64? = nil) {
        let urlString = url.absoluteString
        items.removeAll { $0.urlString == urlString }
        let item = DankDropItem(
            urlString: urlString,
            title: url.lastPathComponent.isEmpty ? (url.host ?? "Link") : url.lastPathComponent,
            subtitle: Self.subtitleForFile(url: url, fileSizeBytes: fileSizeBytes),
            isFile: url.isFileURL,
            fileSizeBytes: fileSizeBytes,
            sfSymbol: Self.sfSymbolForFile(url: url)
        )
        items.insert(item, at: 0)
        trimToMaxItems()
    }

    /// Adds a dropped text payload to the front of the shelf, deduplicating by `textPayload`.
    public mutating func addText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.removeAll { $0.textPayload == trimmed }
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        let item = DankDropItem(
            title: String(firstLine.prefix(60)),
            subtitle: "Text • \(trimmed.count) chars",
            textPayload: trimmed,
            isFile: false,
            sfSymbol: "doc.text.fill"
        )
        items.insert(item, at: 0)
        trimToMaxItems()
    }

    public mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    public mutating func clear() {
        items.removeAll()
    }

    private mutating func trimToMaxItems() {
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
    }

    /// SF Symbol for a dropped file/link, derived from the path extension or URL kind.
    public static func sfSymbolForFile(url: URL) -> String {
        if !url.isFileURL { return "link" }
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "bmp", "svg", "webp":
            return "photo.fill"
        case "mp4", "mov", "m4v", "avi", "mkv", "webm":
            return "film.fill"
        case "mp3", "wav", "aac", "m4a", "flac", "ogg", "aiff":
            return "music.note"
        case "pdf":
            return "doc.richtext.fill"
        case "zip", "tar", "gz", "bz2", "xz", "rar", "7z":
            return "doc.zipper"
        case "txt", "md", "markdown", "rtf", "log":
            return "doc.text.fill"
        case "swift", "py", "js", "ts", "tsx", "jsx", "json", "yaml", "yml", "xml",
             "html", "css", "scss", "c", "h", "cpp", "hpp", "sh", "zsh", "rs", "go":
            return "chevron.left.forwardslash.chevron.right"
        case "app", "dmg", "pkg", "ipa":
            return "app.badge.fill"
        default:
            return "doc.fill"
        }
    }

    /// Subtitle line for a dropped file: extension + size, falling back to location info.
    public static func subtitleForFile(url: URL, fileSizeBytes: Int64?) -> String {
        var parts: [String] = []
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty { parts.append(ext.uppercased()) }
        if let size = fileSizeBytes, size >= 0 {
            parts.append(formatByteCount(size))
        }
        if !parts.isEmpty { return parts.joined(separator: " • ") }
        if url.isFileURL {
            let dir = url.deletingLastPathComponent().lastPathComponent
            return dir.isEmpty ? url.path : dir
        }
        return url.host ?? url.absoluteString
    }

    /// Formats a byte count using the system file-style formatter ("1.4 MB").
    public static func formatByteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
