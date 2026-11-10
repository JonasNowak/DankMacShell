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
    @ObservedObject var configStore = ConfigStore.shared
    @State private var searchText: String = ""

    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private var shortcuts: [ShortcutEntry] {
        let cfg = configStore.config
        return [
            // DMS Shell
            ShortcutEntry(
                category: "DankMaterialShell",
                title: "Spotlight / App Launcher",
                keys: cfg.launcherHotkey ? HotkeyHelper.displayString(key: cfg.launcherHotkeyKey, modifiers: cfg.launcherHotkeyModifiers) : "Disabled"
            ),
            ShortcutEntry(
                category: "DankMaterialShell",
                title: "DankDash Overview",
                keys: cfg.dashHotkey ? HotkeyHelper.displayString(key: cfg.dashHotkeyKey, modifiers: cfg.dashHotkeyModifiers) : "Disabled"
            ),
            ShortcutEntry(
                category: "DankMaterialShell",
                title: "Notepad Scratchpad",
                keys: cfg.notepadHotkey ? HotkeyHelper.displayString(key: cfg.notepadHotkeyKey, modifiers: cfg.notepadHotkeyModifiers) : "Disabled"
            ),
            ShortcutEntry(
                category: "DankMaterialShell",
                title: "Clipboard History",
                keys: cfg.clipboardHotkey ? HotkeyHelper.displayString(key: cfg.clipboardHotkeyKey, modifiers: cfg.clipboardHotkeyModifiers) : "Disabled"
            ),
            ShortcutEntry(
                category: "DankMaterialShell",
                title: "Slanted Wallpaper Picker",
                keys: cfg.wallpaperPickerHotkey ? HotkeyHelper.displayString(key: cfg.wallpaperPickerHotkeyKey, modifiers: cfg.wallpaperPickerHotkeyModifiers) : "Disabled"
            ),
            ShortcutEntry(category: "DankMaterialShell", title: "Control Center", keys: "⌥ C"),
            ShortcutEntry(category: "DankMaterialShell", title: "Power & Session Menu", keys: "⌥ P"),

            // In-panel shortcuts (v0.6)
            ShortcutEntry(category: "In-Panel Shortcuts", title: "Notepad: Find & Replace", keys: "⌘ F", description: "Opens the find & replace bar in the notepad"),
            ShortcutEntry(category: "In-Panel Shortcuts", title: "Notepad: Next Match", keys: "↵", description: "Jumps to the next match while the find bar is open (wraps around)"),
            ShortcutEntry(category: "In-Panel Shortcuts", title: "Clipboard: Copy Selected Item", keys: "↵", description: "Copies the selected history item; auto-pastes into the previous app when enabled"),
            ShortcutEntry(category: "In-Panel Shortcuts", title: "Launcher: Open Actions Panel", keys: "Tab", description: "Toggles the per-app action sidebar, including Edit App…"),

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
    }

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
            .background(themeStore.panelHeaderBackground)

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
            HStack(spacing: 8) {
                Text("\(shortcuts.count) shortcuts available")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: p.outline.hex))
                Spacer()
                Button(action: {
                    SettingsController.shared.show(tab: "shortcuts")
                    onClose()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 10))
                        Text("Configure Shortcuts")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: p.primary.hex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: p.primaryContainer.hex).opacity(0.4))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Text("• Press Esc to close")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: p.outline.hex))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(themeStore.panelHeaderBackground)
        }
        .frame(width: 480, height: 460)
        .background(GlassSurfaceBackground())
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(themeStore.panelBorderColor, lineWidth: 1)
        )
        .shadow(color: themeStore.adaptiveShadowColor(baseOpacity: 0.35), radius: 26, x: 0, y: 12)
    }
}
