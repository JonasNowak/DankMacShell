import SwiftUI
import DMSCore

/// Material 3 Notepad view for quick scratchpad and persistent notes.
public struct NotepadView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var notepad = NotepadService.shared
    @State private var showingList: Bool = false

    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
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
            .background(Color(hex: p.surfaceContainerHigh.hex))

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

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

                // Editor Text Area
                TextEditor(text: Binding(
                    get: { notepad.activeNote.content },
                    set: { notepad.updateActiveNote(content: $0) }
                ))
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(14)
            }

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Footer Status Bar
            HStack {
                Text("\(notepad.activeNote.wordCount) words, \(notepad.activeNote.charCount) characters")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: p.outline.hex))

                Spacer()

                Text("Saved \(notepad.activeNote.updatedAt.formatted(date: .omitted, time: .standard))")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: p.outline.hex))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color(hex: p.surfaceContainerHigh.hex))
        }
        .frame(width: 480, height: 420)
        .background(Color(hex: p.surface.hex))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
    }
}
