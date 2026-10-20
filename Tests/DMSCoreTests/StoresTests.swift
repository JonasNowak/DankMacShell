import Testing
import Foundation
@testable import DMSCore

@Suite("Notepad and Clipboard Stores Tests")
struct StoresTests {

    @Test("ClipboardStore Item Insertion, Deduplication, and Search")
    func testClipboardOperations() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_clip_\(UUID().uuidString).json")
        let store = ClipboardStore(storageURL: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // 1. Rejects empty or whitespace-only text
        #expect(store.add(text: "") == nil)
        #expect(store.add(text: "   \n\t  ") == nil)
        #expect(store.getItems().isEmpty)

        // 2. Add valid item
        let first = store.add(text: "First Item")
        #expect(first != nil)
        #expect(store.getItems().count == 1)

        // 3. Deduplication: adding "First Item" again should not create duplicate, but move to front
        _ = store.add(text: "Second Item")
        #expect(store.getItems().count == 2)
        #expect(store.getItems().first?.text == "Second Item")

        _ = store.add(text: "First Item")
        #expect(store.getItems().count == 2)
        #expect(store.getItems().first?.text == "First Item")

        // 4. Search
        let searchRes = store.search(query: "second")
        #expect(searchRes.count == 1)
        #expect(searchRes.first?.text == "Second Item")

        // Empty search returns all
        #expect(store.search(query: "").count == 2)

        // 5. Remove by ID
        if let toRemove = store.getItems().first {
            store.remove(id: toRemove.id)
            #expect(store.getItems().count == 1)
            #expect(store.getItems().first?.text == "Second Item")
        }

        // 6. Clear
        store.clear()
        #expect(store.getItems().isEmpty)
    }

    @Test("ClipboardItem Preview Truncation and URL Detection")
    func testClipboardItemProperties() {
        // Plain text with newlines
        let text = "Line 1\nLine 2\nLine 3"
        let item = ClipboardItem(text: text)
        #expect(item.characterCount == text.count)
        #expect(item.lineCount == 3)
        #expect(item.isURL == false)
        #expect(item.preview == text)

        // Long text preview truncation (120 chars + "...")
        let longText = String(repeating: "A", count: 200)
        let longItem = ClipboardItem(text: longText)
        #expect(longItem.preview.count == 123)
        #expect(longItem.preview.hasSuffix("..."))

        // URL detection
        let urlItem = ClipboardItem(text: "https://github.com/AvengeMedia/dms-shell")
        #expect(urlItem.isURL == true)

        let nonUrlItem = ClipboardItem(text: "just some regular text with no protocol")
        #expect(nonUrlItem.isURL == false)
    }

    @Test("ClipboardStore Capacity Clamping at 100 Items")
    func testClipboardCapacity() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_clip_cap_\(UUID().uuidString).json")
        let store = ClipboardStore(storageURL: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        for i in 1...115 {
            store.add(text: "Item \(i)")
        }

        #expect(store.getItems().count == 100)
        // Most recent item should be at the front
        #expect(store.getItems().first?.text == "Item 115")
    }

    @Test("ClipboardStore Persistence Across Instances")
    func testClipboardPersistence() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_clip_persist_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store1 = ClipboardStore(storageURL: tmp)
        store1.add(text: "Persistent Clip")

        let store2 = ClipboardStore(storageURL: tmp)
        #expect(store2.getItems().count == 1)
        #expect(store2.getItems().first?.text == "Persistent Clip")
    }

    @Test("NotepadStore Note Creation, Selection, Deletion, and Word Count")
    func testNotepadOperations() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_note_\(UUID().uuidString).json")
        let store = NotepadStore(storageURL: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Initial default note
        let defaultNote = store.getActiveNote()
        #expect(!defaultNote.title.isEmpty)

        // Create new note
        let note2 = store.createNote(title: "Project DMS", content: "Dank Material Shell\nfor macOS desktop environment")
        #expect(note2.title == "Project DMS")
        #expect(note2.wordCount == 7)
        #expect(note2.charCount > 20)
        #expect(store.getActiveNote().id == note2.id)

        // Update active note
        store.updateActiveNote(title: "Project DMS v2", content: "Updated content")
        #expect(store.getActiveNote().title == "Project DMS v2")
        #expect(store.getActiveNote().content == "Updated content")
        #expect(store.getActiveNote().wordCount == 2)

        // Switch active note back to first
        store.setActiveNote(id: defaultNote.id)
        #expect(store.getActiveNote().id == defaultNote.id)

        // Delete active note -> active shifts to remaining note
        store.deleteNote(id: defaultNote.id)
        #expect(store.getNotes().count == 1)
        #expect(store.getActiveNote().id == note2.id)
    }

    @Test("NotepadStore Persistence Across Instances")
    func testNotepadPersistence() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_note_persist_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store1 = NotepadStore(storageURL: tmp)
        _ = store1.createNote(title: "Persisted Note", content: "Persisted Body")

        let store2 = NotepadStore(storageURL: tmp)
        #expect(store2.getNotes().contains(where: { $0.title == "Persisted Note" }))
        #expect(store2.getActiveNote().title == "Persisted Note")
    }
}
