import SwiftUI
import DMSCore

/// Material 3 Notepad view for quick scratchpad and persistent notes.
public struct NotepadView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var notepad = NotepadService.shared
    @ObservedObject var configStore = ConfigStore.shared
    @State private var showingList: Bool = false

    // v0.6 NOTE: find & replace bar state
    @State private var showFindBar: Bool = false
    @State private var findText: String = ""
    @State private var replaceText: String = ""
    @State private var caseSensitive: Bool = false
    @State private var currentMatchIndex: Int = 0
    @State private var focusRange: NSRange? = nil

    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private var previewMode: String {
        configStore.config.notepadPreviewMode
    }

    private var matches: [Range<String.Index>] {
        FindReplaceEngine.matches(in: notepad.activeNote.content, query: findText, caseSensitive: caseSensitive)
    }

    private var safeMatchIndex: Int {
        let count = matches.count
        guard count > 0 else { return 0 }
        return min(max(0, currentMatchIndex), count - 1)
    }

    private func cyclePreviewMode() {
        let next: String
        switch previewMode {
        case "split": next = "full"
        case "full": next = "none"
        default: next = "split"
        }
        configStore.update { $0.notepadPreviewMode = next }
    }

    private func goToMatch(delta: Int) {
        let all = matches
        guard !all.isEmpty else { return }
        currentMatchIndex = delta > 0
            ? FindReplaceEngine.nextIndex(current: safeMatchIndex, matchCount: all.count)
            : FindReplaceEngine.previousIndex(current: safeMatchIndex, matchCount: all.count)
        focusRange = NSRange(all[safeMatchIndex], in: notepad.activeNote.content)
    }

    private func replaceCurrent() {
        let all = matches
        guard !all.isEmpty else { return }
        let newText = FindReplaceEngine.replace(
            text: notepad.activeNote.content,
            match: all[safeMatchIndex],
            with: replaceText
        )
        notepad.replaceActiveNoteContent(newText)
        // Matches recomputed from new content; jump to the match now at this position.
        let updated = matches
        if !updated.isEmpty {
            currentMatchIndex = min(safeMatchIndex, updated.count - 1)
            focusRange = NSRange(updated[currentMatchIndex], in: notepad.activeNote.content)
        }
    }

    private func replaceAllMatches() {
        let result = FindReplaceEngine.replaceAll(
            in: notepad.activeNote.content,
            query: findText,
            replacement: replaceText,
            caseSensitive: caseSensitive
        )
        guard result.count > 0 else { return }
        notepad.replaceActiveNoteContent(result.text)
        currentMatchIndex = 0
        ToastCenter.shared.show(icon: "arrow.2.circlepath", message: "Replaced \(result.count) occurrence\(result.count == 1 ? "" : "s")")
    }

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 0) {
            // Header Bar (with spacing for macOS Server-Side Decorations traffic lights)
            HStack(spacing: 12) {
                Spacer().frame(width: 68)

                Button(action: { showingList.toggle() }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: p.primary.hex))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: p.primaryContainer.hex))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                TextField("Note Title", text: Binding(
                    get: { notepad.activeNote.title },
                    set: { notepad.updateActiveNote(title: $0) }
                ))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .textFieldStyle(.plain)
                .foregroundColor(Color(hex: p.onSurface.hex))

                Spacer()

                // New Note button
                Button(action: { notepad.createNewNote() }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: p.surfaceVariant.hex).opacity(0.6))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Copy note button
                Button(action: {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(notepad.activeNote.content, forType: .string)
                    ToastCenter.shared.show(icon: "doc.on.doc.fill", message: "Note Copied to Clipboard")
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: p.surfaceVariant.hex).opacity(0.6))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Markdown preview toggle (cycles none → split → full)
                Button(action: cyclePreviewMode) {
                    Image(systemName: previewMode == "none" ? "eye" : (previewMode == "split" ? "rectangle.split.2x1.fill" : "eye.fill"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(previewMode == "none" ? Color(hex: p.onSurfaceVariant.hex) : Color(hex: p.primary.hex))
                        .frame(width: 32, height: 32)
                        .background((previewMode == "none" ? Color(hex: p.surfaceVariant.hex) : Color(hex: p.primaryContainer.hex)).opacity(0.6))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(previewMode == "none" ? "Show Markdown preview" : (previewMode == "split" ? "Preview: full" : "Hide preview"))

                // Find & Replace toggle (⌘F)
                Button(action: { showFindBar.toggle() }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(showFindBar ? Color(hex: p.primary.hex) : Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 32, height: 32)
                        .background((showFindBar ? Color(hex: p.primaryContainer.hex) : Color(hex: p.surfaceVariant.hex)).opacity(0.6))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Find & Replace (⌘F)")

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: p.surfaceVariant.hex).opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(themeStore.panelHeaderBackground)

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Find & Replace bar (⌘F)
            if showFindBar {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: p.outline.hex))

                        TextField("Find", text: $findText)
                            .font(.system(size: 12))
                            .textFieldStyle(.plain)
                            .foregroundColor(Color(hex: p.onSurface.hex))

                        Text(matches.isEmpty ? (findText.isEmpty ? "" : "No matches") : "\(safeMatchIndex + 1) of \(matches.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: p.outline.hex))
                            .frame(minWidth: 52, alignment: .trailing)

                        Button(action: { caseSensitive.toggle() }) {
                            Text("Aa")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(caseSensitive ? Color(hex: p.onPrimary.hex) : Color(hex: p.outline.hex))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(caseSensitive ? Color(hex: p.primary.hex) : Color(hex: p.surfaceContainerHigh.hex))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { goToMatch(delta: -1) }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                                .frame(width: 22, height: 22)
                                .background(Color(hex: p.surfaceContainerHigh.hex))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { goToMatch(delta: 1) }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                                .frame(width: 22, height: 22)
                                .background(Color(hex: p.surfaceContainerHigh.hex))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { showFindBar = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: p.outline.hex))
                                .frame(width: 22, height: 22)
                                .background(Color(hex: p.surfaceContainerHigh.hex))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.2.circlepath")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: p.outline.hex))

                        TextField("Replace", text: $replaceText)
                            .font(.system(size: 12))
                            .textFieldStyle(.plain)
                            .foregroundColor(Color(hex: p.onSurface.hex))

                        Button(action: replaceCurrent) {
                            Text("Replace")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: p.primary.hex))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: p.primaryContainer.hex).opacity(0.5))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: replaceAllMatches) {
                            Text("All")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: p.onPrimary.hex))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: p.primary.hex))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: p.surfaceContainerLow.hex))

                Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))
            }

            HStack(spacing: 0) {
                // Optional sidebar of notes
                if showingList {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SAVED NOTES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: p.outline.hex))
                            .padding(.horizontal, 12)
                            .padding(.top, 10)

                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(notepad.notes) { note in
                                    Button(action: { notepad.selectNote(id: note.id) }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                                                    .font(.system(size: 12, weight: note.id == notepad.activeNote.id ? .bold : .medium))
                                                    .foregroundColor(note.id == notepad.activeNote.id ? Color(hex: p.primary.hex) : Color(hex: p.onSurface.hex))
                                                    .lineLimit(1)
                                                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.system(size: 10))
                                                    .foregroundColor(Color(hex: p.outline.hex))
                                            }
                                            Spacer()
                                            if notepad.notes.count > 1 {
                                                Button(action: { notepad.deleteNote(id: note.id) }) {
                                                    Image(systemName: "trash")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(Color(hex: p.error.hex))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(note.id == notepad.activeNote.id ? Color(hex: p.primaryContainer.hex).opacity(0.5) : Color.clear)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(6)
                        }
                    }
                    .frame(width: 160)
                    .background(Color(hex: p.surfaceContainerLow.hex))

                    Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))
                }

                // Editor / Preview area (v0.6 NOTE: split-pane Markdown preview)
                switch previewMode {
                case "split":
                    HStack(spacing: 0) {
                        editorView(palette: p)
                            .frame(maxWidth: .infinity)

                        Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

                        MarkdownPreviewView(markdown: notepad.activeNote.content)
                            .frame(maxWidth: .infinity)
                    }
                case "full":
                    MarkdownPreviewView(markdown: notepad.activeNote.content)
                default:
                    editorView(palette: p)
                }
            }

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Footer Status Bar
            HStack {
                Text("\(notepad.activeNote.wordCount) words, \(notepad.activeNote.charCount) characters")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: p.outline.hex))

                Spacer()

                Text("⌘F Find & Replace • Saved \(notepad.activeNote.updatedAt.formatted(date: .omitted, time: .standard))")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: p.outline.hex))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(themeStore.panelHeaderBackground)
        }
        .frame(minWidth: 480, idealWidth: previewMode == "split" ? 780 : 480, maxWidth: .infinity, minHeight: 360, idealHeight: 420, maxHeight: .infinity)
        .background(GlassSurfaceBackground())
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(themeStore.panelBorderColor, lineWidth: 1)
        )
        .shadow(color: themeStore.adaptiveShadowColor(baseOpacity: 0.32), radius: 24, x: 0, y: 12)
        .onKeyPress { press in
            if press.key == "f" && press.modifiers.contains(.command) {
                showFindBar = true
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if showFindBar {
                goToMatch(delta: 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if showFindBar {
                showFindBar = false
            } else {
                onClose()
            }
            return .handled
        }
        .onChange(of: findText) { _, _ in
            currentMatchIndex = 0
            let all = matches
            if !all.isEmpty {
                focusRange = NSRange(all[0], in: notepad.activeNote.content)
            }
        }
        .onChange(of: caseSensitive) { _, _ in
            currentMatchIndex = 0
        }
        .onChange(of: notepad.activeNote.id) { _, _ in
            showFindBar = false
            findText = ""
            replaceText = ""
            currentMatchIndex = 0
            focusRange = nil
        }
    }

    /// The plain-text editor pane (NSTextView bridge so the find bar can jump to matches).
    @ViewBuilder
    private func editorView(palette p: DMSPalette) -> some View {
        NotepadTextView(
            text: Binding(
                get: { notepad.activeNote.content },
                set: { notepad.updateActiveNote(content: $0) }
            ),
            font: .monospacedSystemFont(ofSize: 13, weight: .regular),
            textColor: NSColor(Color(hex: p.onSurface.hex)),
            backgroundColor: .clear,
            focusRange: $focusRange
        )
    }
}
