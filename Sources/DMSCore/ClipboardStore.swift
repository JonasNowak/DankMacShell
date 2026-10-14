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

    private let lock = NSLock()
    private var items: [ClipboardItem] = []
    private let maxItems: Int = 100
    private let storageURL: URL

    public init(storageURL: URL? = nil) {
        if let custom = storageURL {
            self.storageURL = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dmsDir = appSupport.appendingPathComponent("DMS", isDirectory: true)
            try? FileManager.default.createDirectory(at: dmsDir, withIntermediateDirectories: true)
            self.storageURL = dmsDir.appendingPathComponent("clipboard_history.json")
        }
        load()
    }

    public func getItems() -> [ClipboardItem] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }

    @discardableResult
    public func add(text: String) -> ClipboardItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        lock.lock()
        defer { lock.unlock() }

        // Remove duplicate if already present
        items.removeAll { $0.text == text }

        let item = ClipboardItem(text: text)
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

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let loaded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return
        }
        items = loaded
    }
}
