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

    private let lock = NSLock()
    private var notes: [NoteItem] = []
    private var activeNoteId: UUID?
    private let storageURL: URL

    public init(storageURL: URL? = nil) {
        if let custom = storageURL {
            self.storageURL = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dmsDir = appSupport.appendingPathComponent("DMS", isDirectory: true)
            try? FileManager.default.createDirectory(at: dmsDir, withIntermediateDirectories: true)
            self.storageURL = dmsDir.appendingPathComponent("notes.json")
        }
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
        save()
        return fresh
    }

    public func createNote(title: String = "New Note", content: String = "") -> NoteItem {
        lock.lock()
        defer { lock.unlock() }

        let note = NoteItem(title: title, content: content, updatedAt: Date())
        notes.insert(note, at: 0)
        activeNoteId = note.id
        save()
        return note
    }

    public func updateActiveNote(title: String? = nil, content: String? = nil) {
        lock.lock()
        defer { lock.unlock() }

        guard let id = activeNoteId, let index = notes.firstIndex(where: { $0.id == id }) else {
            let note = NoteItem(title: title ?? "Scratchpad", content: content ?? "")
            notes.insert(note, at: 0)
            activeNoteId = note.id
            save()
            return
        }

        if let title = title {
            notes[index].title = title
        }
        if let content = content {
            notes[index].content = content
        }
        notes[index].updatedAt = Date()
        save()
    }

    public func setActiveNote(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        if notes.contains(where: { $0.id == id }) {
            activeNoteId = id
        }
    }

    public func deleteNote(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        notes.removeAll { $0.id == id }
        if activeNoteId == id {
            activeNoteId = notes.first?.id
        }
        save()
    }

    private func save() {
        struct Container: Codable {
            let notes: [NoteItem]
            let activeId: UUID?
        }
        let container = Container(notes: notes, activeId: activeNoteId)
        guard let data = try? JSONEncoder().encode(container) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        struct Container: Codable {
            let notes: [NoteItem]
            let activeId: UUID?
        }
        guard let data = try? Data(contentsOf: storageURL),
              let container = try? JSONDecoder().decode(Container.self, from: data) else {
            if notes.isEmpty {
                let initial = NoteItem(title: "Scratchpad", content: "Welcome to DankMaterialShell Notepad!\nNotes auto-save instantly.")
                notes.append(initial)
                activeNoteId = initial.id
            }
            return
        }
        notes = container.notes
        activeNoteId = container.activeId ?? notes.first?.id
    }
}
