import Foundation

/// A note stored in DMS Notepad.
public struct NoteItem: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var content: String
    public var updatedAt: Date

    public var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }

    public var charCount: Int {
        content.count
    }

    public init(id: UUID = UUID(), title: String = "Untitled Note", content: String = "", updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.updatedAt = updatedAt
    }
}

/// Thread-safe persistence store for DMS Notepad.
public final class NotepadStore: @unchecked Sendable {
    public static let shared = NotepadStore()

    private struct Container: Codable {
        let notes: [NoteItem]
        let activeId: UUID?
    }

    private let lock = NSLock()
    private var notes: [NoteItem] = []
    private var activeNoteId: UUID?
    private let storageURL: URL
    private let storageDir: URL
    /// Whether `storageDir` is the real DMS application-support directory (permissions enforced there).
    private let enforceDirPermissions: Bool
    /// Dedicated serial queue for all disk writes (no lost-update races between detached tasks).
    private let ioQueue: DispatchQueue

    public init(storageURL: URL? = nil) {
        if let custom = storageURL {
            self.storageURL = custom
            self.storageDir = custom.deletingLastPathComponent()
            self.enforceDirPermissions = false
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library")
                    .appendingPathComponent("Application Support")
            let dmsDir = appSupport.appendingPathComponent("DMS", isDirectory: true)
            try? FileManager.default.createDirectory(at: dmsDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dmsDir.path)
            self.storageURL = dmsDir.appendingPathComponent("notes.json")
            self.storageDir = dmsDir
            self.enforceDirPermissions = true
        }
        self.ioQueue = DispatchQueue(label: "com.dms.notepad.io", qos: .utility)
        load()
    }

    public func getNotes() -> [NoteItem] {
        lock.lock()
        defer { lock.unlock() }
        return notes
    }

    public func getActiveNote() -> NoteItem {
        lock.lock()
        defer { lock.unlock() }

        if let id = activeNoteId, let found = notes.first(where: { $0.id == id }) {
            return found
        }
        if let first = notes.first {
            activeNoteId = first.id
            return first
        }
        let fresh = NoteItem(title: "Scratchpad", content: "")
        notes.append(fresh)
        activeNoteId = fresh.id
        saveLocked()
        return fresh
    }

    public func createNote(title: String = "New Note", content: String = "") -> NoteItem {
        lock.lock()
        defer { lock.unlock() }

        let note = NoteItem(title: title, content: content, updatedAt: Date())
        notes.insert(note, at: 0)
        activeNoteId = note.id
        saveLocked()
        return note
    }

    public func updateActiveNote(title: String? = nil, content: String? = nil) {
        lock.lock()
        defer { lock.unlock() }

        if let id = activeNoteId, notes.contains(where: { $0.id == id }) {
            updateNoteLocked(id: id, title: title, content: content)
        } else {
            let note = NoteItem(title: title ?? "Scratchpad", content: content ?? "")
            notes.insert(note, at: 0)
            activeNoteId = note.id
            saveLocked()
        }
    }

    /// Updates a specific note by UUID without racing against `activeNoteId`.
    public func updateNote(id: UUID, title: String? = nil, content: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        updateNoteLocked(id: id, title: title, content: content)
    }

    private func updateNoteLocked(id: UUID, title: String? = nil, content: String? = nil) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        if let title = title {
            notes[index].title = title
        }
        if let content = content {
            notes[index].content = content
        }
        notes[index].updatedAt = Date()
        saveLocked()
    }

    public func setActiveNote(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        if notes.contains(where: { $0.id == id }) {
            activeNoteId = id
            saveLocked()
        }
    }

    public func deleteNote(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        notes.removeAll { $0.id == id }
        if activeNoteId == id {
            activeNoteId = notes.first?.id
        }
        saveLocked()
    }

    /// Blocks until all queued disk writes have completed (call on app termination).
    public func flushSync() {
        ioQueue.sync {}
    }

    // MARK: - Persistence

    /// Serializes a snapshot of the current state onto the dedicated IO queue.
    /// Callers must hold `lock`.
    private func saveLocked() {
        let container = Container(notes: notes, activeId: activeNoteId)
        guard let data = try? JSONEncoder().encode(container) else { return }
        let target = storageURL
        let dir = storageDir
        let enforceDir = enforceDirPermissions
        ioQueue.async {
            do {
                if !FileManager.default.fileExists(atPath: dir.path) {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                }
                if enforceDir {
                    try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
                }
                try data.write(to: target, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            } catch {
                // Ignore background write failures
            }
        }
    }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL) else {
            seedInitialIfEmpty()
            return
        }
        do {
            let container = try JSONDecoder().decode(Container.self, from: data)
            lock.lock()
            notes = container.notes
            activeNoteId = container.activeId ?? notes.first?.id
            lock.unlock()
        } catch {
            // Back up the corrupted file before resetting to a fresh state.
            let stamp = String(format: "%.0f", Date().timeIntervalSince1970)
            let backup = storageDir.appendingPathComponent("notes.json.corrupt-\(stamp)")
            try? fm.moveItem(at: storageURL, to: backup)
            seedInitialIfEmpty()
        }
    }

    private func seedInitialIfEmpty() {
        lock.lock()
        defer { lock.unlock() }
        if notes.isEmpty {
            let initial = NoteItem(title: "Scratchpad", content: "Welcome to DankMaterialShell Notepad!\nNotes auto-save instantly.")
            notes.append(initial)
            activeNoteId = initial.id
        }
    }
}
