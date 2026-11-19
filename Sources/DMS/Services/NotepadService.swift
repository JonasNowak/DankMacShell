import Foundation
import DMSCore

/// Manages active notes and synchronization with NotepadStore.
@MainActor
public final class NotepadService: ObservableObject {
    public static let shared = NotepadService()

    @Published public var activeNote: NoteItem
    @Published public private(set) var notes: [NoteItem] = []

    private var saveTask: Task<Void, Never>?
    /// Serializes the debounced write against synchronous flushes so a pending save can
    /// never land on a different note after the active note changed.
    private let saveLock = NSLock()

    private init() {
        self.activeNote = NotepadStore.shared.getActiveNote()
        self.notes = NotepadStore.shared.getNotes()
    }

    public func updateActiveNote(title: String? = nil, content: String? = nil) {
        if let title = title {
            activeNote.title = title
        }
        if let content = content {
            activeNote.content = content
        }
        activeNote.updatedAt = Date()
        if let idx = notes.firstIndex(where: { $0.id == activeNote.id }) {
            notes[idx] = activeNote
        }

        let targetNoteID = activeNote.id
        let currentTitle = activeNote.title
        let currentContent = activeNote.content
        let lock = saveLock
        saveTask?.cancel()
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            lock.withLock {
                guard !Task.isCancelled else { return }
                // Only write when the store's active note is still the one we captured;
                // selectNote/createNewNote/deleteNote flush synchronously before switching.
                guard NotepadStore.shared.getActiveNote().id == targetNoteID else { return }
                NotepadStore.shared.updateActiveNote(title: currentTitle, content: currentContent)
            }
        }
    }

    /// Replaces the whole content of the active note (used by the find & replace bar).
    public func replaceActiveNoteContent(_ content: String) {
        updateActiveNote(content: content)
    }

    /// Synchronously writes any pending edit to the store BEFORE the active note id
    /// changes, cancelling the debounced task first and writing under the save lock.
    public func flushPendingSave() {
        saveLock.lock()
        defer { saveLock.unlock() }
        saveTask?.cancel()
        saveTask = nil
        NotepadStore.shared.updateActiveNote(title: activeNote.title, content: activeNote.content)
    }

    public func createNewNote(title: String = "New Note", content: String = "") {
        flushPendingSave()
        let note = NotepadStore.shared.createNote(title: title, content: content)
        self.activeNote = note
        self.notes = NotepadStore.shared.getNotes()
    }

    public func selectNote(id: UUID) {
        flushPendingSave()
        NotepadStore.shared.setActiveNote(id: id)
        self.activeNote = NotepadStore.shared.getActiveNote()
        self.notes = NotepadStore.shared.getNotes()
    }

    public func deleteNote(id: UUID) {
        flushPendingSave()
        NotepadStore.shared.deleteNote(id: id)
        self.activeNote = NotepadStore.shared.getActiveNote()
        self.notes = NotepadStore.shared.getNotes()
    }
}
