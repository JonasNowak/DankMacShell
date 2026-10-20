import Foundation
import DMSCore

/// Manages active notes and synchronization with NotepadStore.
@MainActor
public final class NotepadService: ObservableObject {
    public static let shared = NotepadService()

    @Published public var activeNote: NoteItem
    @Published public private(set) var notes: [NoteItem] = []

    private var saveTask: Task<Void, Never>?

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

        let currentTitle = activeNote.title
        let currentContent = activeNote.content
        saveTask?.cancel()
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            NotepadStore.shared.updateActiveNote(title: currentTitle, content: currentContent)
        }
    }

    public func flushPendingSave() {
        if saveTask != nil {
            saveTask?.cancel()
            saveTask = nil
            NotepadStore.shared.updateActiveNote(title: activeNote.title, content: activeNote.content)
        }
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
