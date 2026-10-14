import Foundation
import DMSCore

/// Manages active notes and synchronization with NotepadStore.
@MainActor
public final class NotepadService: ObservableObject {
    public static let shared = NotepadService()

    @Published public var activeNote: NoteItem
    @Published public private(set) var notes: [NoteItem] = []

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
        NotepadStore.shared.updateActiveNote(title: title, content: content)
        self.notes = NotepadStore.shared.getNotes()
    }

    public func createNewNote(title: String = "New Note", content: String = "") {
        let note = NotepadStore.shared.createNote(title: title, content: content)
        self.activeNote = note
        self.notes = NotepadStore.shared.getNotes()
    }

    public func selectNote(id: UUID) {
        NotepadStore.shared.setActiveNote(id: id)
        self.activeNote = NotepadStore.shared.getActiveNote()
        self.notes = NotepadStore.shared.getNotes()
    }

    public func deleteNote(id: UUID) {
        NotepadStore.shared.deleteNote(id: id)
        self.activeNote = NotepadStore.shared.getActiveNote()
        self.notes = NotepadStore.shared.getNotes()
    }
}
