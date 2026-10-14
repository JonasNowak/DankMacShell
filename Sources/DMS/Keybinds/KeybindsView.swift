import SwiftUI
import DMSCore

public struct ShortcutEntry: Identifiable, Sendable {
    public var id: String { keys + title }
    public let category: String
    public let title: String
    public let keys: String
    public let description: String

    public init(category: String, title: String, keys: String, description: String = "") {
        self.category = category
        self.title = title
        self.keys = keys
        self.description = description
    }
}

/// Material 3 Keybinds Cheatsheet modal view.
public struct KeybindsView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @State private var searchText: String = ""

    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private let shortcuts: [ShortcutEntry] = [
        // DMS Shell
        ShortcutEntry(category: "DankMaterialShell", title: "Spotlight / App Launcher", keys: "⌥ Space"),
        ShortcutEntry(category: "DankMaterialShell", title: "DankDash Overview", keys: "⌥ D"),
        ShortcutEntry(category: "DankMaterialShell", title: "Notepad Scratchpad", keys: "⌥ N"),
        ShortcutEntry(category: "DankMaterialShell", title: "Clipboard History", keys: "⌥ V"),
        ShortcutEntry(category: "DankMaterialShell", title: "Control Center", keys: "⌥ C"),
        ShortcutEntry(category: "DankMaterialShell", title: "Power & Session Menu", keys: "⌥ P"),

        // Navigation
        ShortcutEntry(category: "Navigation & Windows", title: "Switch Space Left", keys: "^ ←"),
        ShortcutEntry(category: "Navigation & Windows", title: "Switch Space Right", keys: "^ →"),
        ShortcutEntry(category: "Navigation & Windows", title: "Mission Control / Overview", keys: "^ ↑"),
        ShortcutEntry(category: "Navigation & Windows", title: "Application Windows", keys: "^ ↓"),
        ShortcutEntry(category: "Navigation & Windows", title: "Toggle Fullscreen", keys: "^ ⌘ F"),
        ShortcutEntry(category: "Navigation & Windows", title: "Application Switcher", keys: "⌘ Tab"),

        // System
        ShortcutEntry(category: "System Actions", title: "Lock Screen", keys: "^ ⌘ Q"),
        ShortcutEntry(category: "System Actions", title: "Sleep Screen", keys: "⌥ ⌘ Power"),
        ShortcutEntry(category: "System Actions", title: "Interactive Screen Capture", keys: "⇧ ⌘ 4"),
        ShortcutEntry(category: "System Actions", title: "Force Quit Applications", keys: "⌥ ⌘ Esc")
    ]

    private var filteredCategories: [String] {
        let matching = shortcuts.filter {
            searchText.isEmpty ||
            $0.title.lowercased().contains(searchText.lowercased()) ||
            $0.keys.lowercased().contains(searchText.lowercased()) ||
            $0.category.lowercased().contains(searchText.lowercased())
        }
        return Array(Set(matching.map { $0.category })).sorted()
    }

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "command")
                    .foregroundColor(Color(hex: p.primary.hex))

                Text("Keyboard Shortcuts")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: p.onSurface.hex))

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: p.surfaceVariant.hex))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(hex: p.surfaceContainerHigh.hex))

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Search Filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: p.outline.hex))
                TextField("Search shortcuts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: p.onSurface.hex))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: p.surfaceContainerLow.hex))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Shortcuts List
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(filteredCategories, id: \.self) { cat in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cat.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: p.primary.hex))
                                .padding(.horizontal, 4)

                            VStack(spacing: 6) {
                                ForEach(shortcuts.filter { $0.category == cat }) { entry in
                                    HStack {
                                        Text(entry.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color(hex: p.onSurface.hex))
                                        Spacer()
                                        Text(entry.keys)
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(Color(hex: p.primary.hex))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(hex: p.primaryContainer.hex))
                                            .cornerRadius(6)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: p.surfaceContainerLow.hex))
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Footer
            HStack {
                Text("\(shortcuts.count) shortcuts available")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: p.outline.hex))
                Spacer()
                Text("Press Esc to close")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: p.outline.hex))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color(hex: p.surfaceContainerHigh.hex))
        }
        .frame(width: 480, height: 460)
        .background(Color(hex: p.surface.hex))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 26, x: 0, y: 12)
    }
}
