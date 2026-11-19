import Foundation

/// Item stored in DMS clipboard history.
public struct ClipboardItem: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public let text: String
    public let preview: String
    public let characterCount: Int
    public let lineCount: Int
    public let createdAt: Date
    public let isURL: Bool

    public init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 120 {
            self.preview = String(trimmed.prefix(120)) + "..."
        } else {
            self.preview = trimmed
        }

        self.characterCount = text.count
        self.lineCount = text.components(separatedBy: .newlines).count

        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            self.isURL = true
        } else {
            self.isURL = false
        }
    }
}

/// Thread-safe store for DMS clipboard history.
public final class ClipboardStore: @unchecked Sendable {
    public static let shared = ClipboardStore()

    /// Maximum UTF-8 bytes of text retained per history item (256 KB) — larger payloads freeze the UI.
    public static let maxItemTextBytes = 262_144

    private let lock = NSLock()
    private var items: [ClipboardItem] = []
    private var maxItems: Int = 100
    private let storageURL: URL
    /// Dedicated serial queue for all disk writes so the store lock is never held during I/O.
    /// Shared across instances so a fresh instance can drain pending writes before loading.
    private static let ioQueue = DispatchQueue(label: "com.dank.macshell.clipboardstore.io", qos: .utility)

    /// Maximum history items retained. Settable so `ClipboardService` can push `clipboardMaxItems` from config.
    /// Lowering the cap trims existing items immediately.
    public var maxItemsValue: Int {
        get {
            lock.lock()
            defer { lock.unlock() }
            return maxItems
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            maxItems = max(1, newValue)
            if items.count > maxItems {
                items = Array(items.prefix(maxItems))
                save()
            }
        }
    }

    public init(storageURL: URL? = nil) {
        if let custom = storageURL {
            self.storageURL = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support", isDirectory: true)
            let dmsDir = appSupport.appendingPathComponent("DMS", isDirectory: true)
            try? FileManager.default.createDirectory(at: dmsDir, withIntermediateDirectories: true)
            // Clipboard history is sensitive: keep the DMS app-support dir private.
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dmsDir.path)
            self.storageURL = dmsDir.appendingPathComponent("clipboard_history.json")
        }
        load()
    }

    /// Truncates `text` to at most `maxBytes` UTF-8 bytes without splitting a multi-byte character.
    public static func capText(_ text: String, maxBytes: Int = maxItemTextBytes) -> String {
        guard text.utf8.count > maxBytes else { return text }
        var used = 0
        var out = String()
        out.reserveCapacity(text.count)
        for ch in text {
            let n = ch.utf8.count
            if used + n > maxBytes { break }
            out.append(ch)
            used += n
        }
        return out
    }

    public func getItems() -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }

    @discardableResult
    public func add(text: String) -> ClipboardItem? {
        let capped = Self.capText(text)
        let trimmed = capped.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        lock.lock()
        defer { lock.unlock() }

        // Remove duplicate if already present
        items.removeAll { $0.text == capped }

        let item = ClipboardItem(text: capped)
        items.insert(item, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        save()
        return item
    }

    public func remove(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        items.removeAll { $0.id == id }
        save()
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        items.removeAll()
        save()
    }

    public func search(query: String) -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return items }
        return items.filter { $0.text.lowercased().contains(clean) }
    }

    /// Snapshots the current items and persists them on the serial I/O queue.
    /// Callers hold `lock`; the disk write itself happens off the lock.
    private func save() {
        let snapshot = items
        let url = storageURL
        Self.ioQueue.async {
            Self.persist(items: snapshot, to: url)
        }
    }

    /// Writes the history file atomically with `0600` POSIX permissions (and `0700` on its directory).
    private static func persist(items: [ClipboardItem], to url: URL) {
        let fm = FileManager.default
        guard let data = try? JSONEncoder().encode(items) else { return }
        let dir = url.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        let tmp = dir.appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        guard fm.createFile(atPath: tmp.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
            return
        }
        if rename(tmp.path, url.path) != 0 {
            try? fm.removeItem(at: tmp)
            try? data.write(to: url, options: .atomic)
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }

    private func load() {
        let fm = FileManager.default
        // Drain pending writes from any instance sharing the I/O queue so a fresh
        // instance observes everything earlier instances have already added.
        Self.ioQueue.sync {}
        guard let data = try? Data(contentsOf: storageURL) else { return }
        if let loaded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            lock.lock()
            items = loaded
            lock.unlock()
            return
        }
        // Decode failure: back up the corrupted file before resetting so nothing is silently lost.
        let backup = storageURL.deletingLastPathComponent()
            .appendingPathComponent("\(storageURL.lastPathComponent).corrupt-\(Self.corruptTimestamp())")
        try? fm.copyItem(at: storageURL, to: backup)
        lock.lock()
        items = []
        lock.unlock()
    }

    private static func corruptTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}
