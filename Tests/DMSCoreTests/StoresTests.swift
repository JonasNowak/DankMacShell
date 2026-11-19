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

    @Test("ClipboardStore Configurable maxItems Eviction (v0.6)")
    func testClipboardMaxItemsConfigurable() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_clip_max_\(UUID().uuidString).json")
        let store = ClipboardStore(storageURL: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        store.maxItemsValue = 5
        #expect(store.maxItemsValue == 5)

        for i in 1...8 {
            store.add(text: "Item \(i)")
        }
        #expect(store.getItems().count == 5)
        #expect(store.getItems().first?.text == "Item 8")
        #expect(store.getItems().last?.text == "Item 4")

        // Clamped to a minimum of 1
        store.maxItemsValue = 0
        #expect(store.maxItemsValue == 1)
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
        store1.flushSync() // disk writes are serialized on a background queue; flush before reload

        let store2 = NotepadStore(storageURL: tmp)
        #expect(store2.getNotes().contains(where: { $0.title == "Persisted Note" }))
        #expect(store2.getActiveNote().title == "Persisted Note")
    }

    @Test("NotepadStore updateNote(id:) Targets a Specific Note Without Touching the Active One")
    func testNotepadUpdateNoteById() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_note_byid_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store = NotepadStore(storageURL: tmp)
        let active = store.getActiveNote()
        let other = store.createNote(title: "Other", content: "original")
        #expect(store.getActiveNote().id == other.id)

        // Update the non-active note by UUID
        store.updateNote(id: active.id, title: "Renamed", content: "new body")
        let updated = store.getNotes().first { $0.id == active.id }
        #expect(updated?.title == "Renamed")
        #expect(updated?.content == "new body")
        // Active note is untouched by the targeted update
        #expect(store.getActiveNote().id == other.id)
        #expect(store.getActiveNote().title == "Other")

        // Unknown UUID is a no-op
        store.updateNote(id: UUID(), content: "ghost")
        #expect(store.getNotes().count == 2)

        // Persisted to disk
        store.flushSync()
        let store2 = NotepadStore(storageURL: tmp)
        #expect(store2.getNotes().first { $0.id == active.id }?.content == "new body")
    }

    @Test("NotepadStore setActiveNote(id:) Is Persisted")
    func testNotepadSetActiveNotePersisted() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_note_active_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store1 = NotepadStore(storageURL: tmp)
        let first = store1.getActiveNote()
        let second = store1.createNote(title: "Second", content: "")
        store1.setActiveNote(id: first.id)
        store1.flushSync()
        #expect(store1.getActiveNote().id == first.id)

        let store2 = NotepadStore(storageURL: tmp)
        #expect(store2.getActiveNote().id == first.id)
        #expect(store2.getActiveNote().id != second.id)
    }

    @Test("NotepadStore Backs Up Corrupted notes.json Before Resetting")
    func testNotepadCorruptBackup() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_note_corrupt_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let tmp = dir.appendingPathComponent("notes.json")

        // Write garbage that is not valid JSON
        try? "{ this is not json !!!".write(to: tmp, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: tmp.path))

        let store = NotepadStore(storageURL: tmp)
        // Corrupted file was moved aside to notes.json.corrupt-<timestamp>
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let backups = contents.filter { $0.hasPrefix("notes.json.corrupt-") }
        #expect(backups.count == 1)
        #expect(!FileManager.default.fileExists(atPath: tmp.path))
        // Store reset to a fresh seeded note
        #expect(!store.getNotes().isEmpty)
    }

    @Test("NotepadStore Writes notes.json With 0600 Permissions and flushSync Drains the Queue")
    func testNotepadFilePermissionsAndFlush() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_note_perms_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store = NotepadStore(storageURL: tmp)
        _ = store.createNote(title: "Perm Note", content: "body")
        store.flushSync()

        #expect(FileManager.default.fileExists(atPath: tmp.path))
        let attrs = try? FileManager.default.attributesOfItem(atPath: tmp.path)
        let perms = attrs?[.posixPermissions] as? Int
        #expect(perms == 0o600)

        // flushSync returns only after queued writes completed: file decodes immediately
        let data = try? Data(contentsOf: tmp)
        #expect(data != nil)
    }

    @Test("LauncherFrecencyStore Prunes Entries Beyond 500 by Oldest lastLaunchedAt")
    func testFrecencyStorePruning() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_frec_prune_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store = LauncherFrecencyStore(fileURL: tmp)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // 600 distinct ids, oldest first
        for i in 0..<600 {
            store.recordLaunch(id: "app.\(i)", date: base.addingTimeInterval(Double(i)))
        }

        // Oldest 100 evicted, newest 500 kept
        #expect(store.launchInfo(for: "app.0").count == 0)
        #expect(store.launchInfo(for: "app.99").count == 0)
        #expect(store.launchInfo(for: "app.100").count == 1)
        #expect(store.launchInfo(for: "app.599").count == 1)
        #expect(store.launchInfo(for: "app.599").lastLaunch == base.addingTimeInterval(599))

        // Persisted snapshot is also capped at 500 (poll briefly for the async serial write)
        var persistedCount = -1
        for _ in 0..<40 {
            if let data = try? Data(contentsOf: tmp),
               let decoded = try? JSONDecoder().decode([String: FrecencyEntry].self, from: data) {
                persistedCount = decoded.count
                if persistedCount == 500 { break }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        #expect(persistedCount == 500)
    }
}
