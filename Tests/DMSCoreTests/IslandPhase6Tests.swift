import Testing
import Foundation
@testable import DMSCore

@Suite("Phase 6: DankDrop File-Drop Shelf & Pomodoro Live Activity (Island)")
struct IslandPhase6Tests {

    // MARK: - IslandActivity.parse aliases

    @Test("IslandActivity.parse maps timer/pomodoro/focus to .timer")
    func testParseTimerAliases() {
        #expect(IslandActivity.parse("timer") == .timer)
        #expect(IslandActivity.parse("pomodoro") == .timer)
        #expect(IslandActivity.parse("focus") == .timer)
        #expect(IslandActivity.parse("POMODORO") == .timer)
        #expect(IslandActivity.parse(" Timer ") == .timer)
        #expect(IslandActivity.parse("timer").rawValue == "timer")
    }

    @Test("IslandActivity.parse maps drop/filedrop/dankdrop/shelf/files to .fileDrop")
    func testParseFileDropAliases() {
        #expect(IslandActivity.parse("drop") == .fileDrop)
        #expect(IslandActivity.parse("filedrop") == .fileDrop)
        #expect(IslandActivity.parse("dankdrop") == .fileDrop)
        #expect(IslandActivity.parse("shelf") == .fileDrop)
        #expect(IslandActivity.parse("files") == .fileDrop)
        #expect(IslandActivity.parse("DANKDROP") == .fileDrop)
        #expect(IslandActivity.parse("fileDrop").rawValue == "fileDrop")
    }

    @Test("IslandActivity.parse still defaults unknown/empty input to .home")
    func testParseFallback() {
        #expect(IslandActivity.parse(nil) == .home)
        #expect(IslandActivity.parse("") == .home)
        #expect(IslandActivity.parse("nonsense") == .home)
    }

    // MARK: - IslandPresentationState for the new states

    @Test("New presentation states expose isExpanded and activity correctly")
    func testPresentationStateTimerAndFileDrop() throws {
        #expect(!IslandPresentationState.compactTimer.isExpanded)
        #expect(IslandPresentationState.compactTimer.activity == .timer)
        #expect(IslandPresentationState.expandedTimer.isExpanded)
        #expect(IslandPresentationState.expandedTimer.activity == .timer)
        #expect(!IslandPresentationState.compactFileDrop.isExpanded)
        #expect(IslandPresentationState.compactFileDrop.activity == .fileDrop)
        #expect(IslandPresentationState.expandedFileDrop.isExpanded)
        #expect(IslandPresentationState.expandedFileDrop.activity == .fileDrop)

        // Codable roundtrip
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for state in [IslandPresentationState.compactTimer, .expandedTimer, .compactFileDrop, .expandedFileDrop] {
            let decoded = try decoder.decode(IslandPresentationState.self, from: encoder.encode(state))
            #expect(decoded == state)
            #expect(decoded.isExpanded == state.isExpanded)
            #expect(decoded.activity == state.activity)
        }
    }

    // MARK: - Priority arbitration: OSD > FileDrop > Notification > Timer > Media > Idle

    @Test("IslandStateMachine priority arbitration OSD > FileDrop > Notification > Timer > Media > Idle")
    func testPriorityArbitration() {
        var sm = IslandStateMachine()
        #expect(sm.resolveState() == .idle)

        sm.isMediaPlaying = true
        #expect(sm.resolveState() == .compactMedia)

        sm.isTimerRunning = true
        #expect(sm.resolveState() == .compactTimer)

        sm.triggerNotification()
        #expect(sm.resolveState() == .compactNotification)

        sm.isFileDropTargeted = true
        #expect(sm.resolveState() == .compactFileDrop)

        sm.triggerOSD()
        #expect(sm.resolveState() == .compactOSD)
    }

    @Test("FileDrop and Timer respect enabledModules gating")
    func testPriorityRespectsEnabledModules() {
        var sm = IslandStateMachine(enabledModules: [.home, .media])
        sm.isTimerRunning = true
        sm.isFileDropTargeted = true
        sm.isMediaPlaying = true
        #expect(sm.resolveState() == .compactMedia)

        sm.isMediaPlaying = false
        #expect(sm.resolveState() == .idle)
    }

    @Test("Expanded .timer and .fileDrop resolve to expanded states")
    func testExpandedTimerAndFileDropResolution() {
        var sm = IslandStateMachine()
        sm.expand(to: .timer)
        #expect(sm.resolveState() == .expandedTimer)

        sm.expand(to: .fileDrop)
        #expect(sm.resolveState() == .expandedFileDrop)

        sm.collapse()
        #expect(sm.resolveState() == .idle)
    }

    @Test("OSD expiry falls through to FileDrop when targeted")
    func testOSDExpiryFallsThroughToFileDrop() {
        var sm = IslandStateMachine()
        let now = Date()
        sm.isFileDropTargeted = true
        sm.triggerOSD(at: now, duration: 3.0)
        #expect(sm.resolveState(at: now) == .compactOSD)
        #expect(sm.resolveState(at: now.addingTimeInterval(3.5)) == .compactFileDrop)
    }

    // MARK: - targetGeometry for the new states

    @Test("targetGeometry for compactTimer/compactFileDrop/expandedTimer/expandedFileDrop (external display)")
    func testTargetGeometryNewStatesExternalDisplay() {
        let settings = IslandSettings()
        let notch = ScreenNotchGeometry.standardMonitor()

        let compactTimer = IslandStateMachine.targetGeometry(for: .compactTimer, settings: settings, notch: notch)
        #expect(compactTimer.width == 224.0)
        #expect(compactTimer.height == settings.compactIslandHeight)
        #expect(compactTimer.bottomLeftRadius == compactTimer.height / 2.0)

        let compactFileDrop = IslandStateMachine.targetGeometry(for: .compactFileDrop, settings: settings, notch: notch)
        #expect(compactFileDrop.width == 280.0)
        #expect(compactFileDrop.height == 44.0)

        let expandedTimer = IslandStateMachine.targetGeometry(for: .expandedTimer, settings: settings, notch: notch)
        #expect(expandedTimer.width == settings.expandedWidth)
        #expect(expandedTimer.height == settings.expandedHeight)
        #expect(expandedTimer.bottomLeftRadius == 34.0)

        let expandedFileDrop = IslandStateMachine.targetGeometry(for: .expandedFileDrop, settings: settings, notch: notch)
        #expect(expandedFileDrop.width == settings.expandedWidth)
        #expect(expandedFileDrop.height == settings.expandedHeight)
        #expect(expandedFileDrop.bottomLeftRadius == 34.0)
    }

    @Test("targetGeometry for compactTimer/compactFileDrop on a notched MacBook")
    func testTargetGeometryNewStatesNotched() {
        var settings = IslandSettings()
        settings.instance = .notch
        let notch = ScreenNotchGeometry.notchedMacBook()

        let compactTimer = IslandStateMachine.targetGeometry(for: .compactTimer, settings: settings, notch: notch)
        #expect(compactTimer.width == notch.notchWidth + 240.0)
        #expect(compactTimer.height == notch.notchHeight)
        #expect(compactTimer.topLeftRadius == 0.0)
        #expect(compactTimer.offsetY == 0.0)

        let compactFileDrop = IslandStateMachine.targetGeometry(for: .compactFileDrop, settings: settings, notch: notch)
        #expect(compactFileDrop.width == notch.notchWidth + 280.0)
        #expect(compactFileDrop.height == 44.0)
        #expect(compactFileDrop.topLeftRadius == 0.0)
    }

    // MARK: - DankDropStore

    @Test("DankDropStore.addFile inserts a file item at the front with metadata")
    func testDankDropAddFile() {
        var store = DankDropStore()
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        store.addFile(url: url, fileSizeBytes: 2048)

        #expect(store.items.count == 1)
        let item = store.items[0]
        #expect(item.isFile)
        #expect(item.urlString == url.absoluteString)
        #expect(item.title == "report.pdf")
        #expect(item.fileSizeBytes == 2048)
        #expect(item.sfSymbol == "doc.richtext.fill")
        #expect(item.textPayload == nil)
        #expect(item.formattedFileSize != nil)
        #expect(item.subtitle.contains("PDF"))
    }

    @Test("DankDropStore deduplicates by urlString and promotes most recent to front")
    func testDankDropFileDeduplicationAndPromotion() {
        var store = DankDropStore()
        let urlA = URL(fileURLWithPath: "/tmp/a.png")
        let urlB = URL(fileURLWithPath: "/tmp/b.png")
        store.addFile(url: urlA)
        store.addFile(url: urlB)
        #expect(store.items.count == 2)
        #expect(store.items[0].urlString == urlB.absoluteString)

        // Re-adding A dedups and promotes it back to the front
        store.addFile(url: urlA, fileSizeBytes: 10)
        #expect(store.items.count == 2)
        #expect(store.items[0].urlString == urlA.absoluteString)
        #expect(store.items[0].fileSizeBytes == 10)
        #expect(store.items[1].urlString == urlB.absoluteString)
    }

    @Test("DankDropStore.addText stores text payload, ignores blank text, dedups by payload")
    func testDankDropAddText() {
        var store = DankDropStore()
        store.addText("  hello world  ")
        #expect(store.items.count == 1)
        let item = store.items[0]
        #expect(!item.isFile)
        #expect(item.textPayload == "hello world")
        #expect(item.urlString == nil)
        #expect(item.sfSymbol == "doc.text.fill")
        #expect(item.title == "hello world")

        // Blank text is ignored
        store.addText("   \n  ")
        #expect(store.items.count == 1)

        // Same payload dedups instead of duplicating
        store.addText("hello world")
        #expect(store.items.count == 1)

        // Multi-line text keeps first line as title
        store.addText("line one\nline two")
        #expect(store.items.count == 2)
        #expect(store.items[0].title == "line one")
        #expect(store.items[0].textPayload == "line one\nline two")
    }

    @Test("DankDropStore enforces maxItems cap keeping most recent items")
    func testDankDropMaxItemsCap() {
        var store = DankDropStore(maxItems: 3)
        for i in 0..<5 {
            store.addFile(url: URL(fileURLWithPath: "/tmp/file\(i).txt"))
        }
        #expect(store.items.count == 3)
        #expect(store.items[0].title == "file4.txt")
        #expect(store.items[2].title == "file2.txt")
    }

    @Test("DankDropStore.remove and clear")
    func testDankDropRemoveAndClear() {
        var store = DankDropStore()
        store.addFile(url: URL(fileURLWithPath: "/tmp/a.txt"))
        store.addText("some text")
        #expect(store.items.count == 2)
        #expect(store.items[0].textPayload == "some text") // most recent first

        let fileId = store.items[1].id
        store.remove(id: fileId)
        #expect(store.items.count == 1)
        #expect(store.items[0].textPayload == "some text")

        // Removing an unknown id is a no-op
        store.remove(id: UUID())
        #expect(store.items.count == 1)

        store.clear()
        #expect(store.items.isEmpty)
    }

    @Test("DankDropStore and DankDropItem are Codable roundtrip-stable")
    func testDankDropCodableRoundtrip() throws {
        var store = DankDropStore(maxItems: 7)
        store.addFile(url: URL(string: "https://example.com/page")!, fileSizeBytes: nil)
        store.addText("clip me")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DankDropStore.self, from: encoder.encode(store))
        #expect(decoded == store)
        #expect(decoded.maxItems == 7)
        #expect(decoded.items.count == 2)
        #expect(decoded.items[0].textPayload == "clip me")
        #expect(decoded.items[1].urlString == "https://example.com/page")
        #expect(decoded.items[1].sfSymbol == "link")
    }

    @Test("DankDropStore.sfSymbolForFile maps common extensions")
    func testSfSymbolMapping() {
        #expect(DankDropStore.sfSymbolForFile(url: URL(fileURLWithPath: "/x/photo.JPG")) == "photo.fill")
        #expect(DankDropStore.sfSymbolForFile(url: URL(fileURLWithPath: "/x/movie.mov")) == "film.fill")
        #expect(DankDropStore.sfSymbolForFile(url: URL(fileURLWithPath: "/x/song.mp3")) == "music.note")
        #expect(DankDropStore.sfSymbolForFile(url: URL(fileURLWithPath: "/x/doc.pdf")) == "doc.richtext.fill")
        #expect(DankDropStore.sfSymbolForFile(url: URL(fileURLWithPath: "/x/archive.zip")) == "doc.zipper")
        #expect(DankDropStore.sfSymbolForFile(url: URL(fileURLWithPath: "/x/notes.md")) == "doc.text.fill")
        #expect(DankDropStore.sfSymbolForFile(url: URL(fileURLWithPath: "/x/main.swift")) == "chevron.left.forwardslash.chevron.right")
        #expect(DankDropStore.sfSymbolForFile(url: URL(fileURLWithPath: "/x/blob.bin")) == "doc.fill")
        #expect(DankDropStore.sfSymbolForFile(url: URL(string: "https://example.com")!) == "link")
    }
}
