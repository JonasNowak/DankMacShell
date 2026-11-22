import SwiftUI
import AppKit
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

/// Static specification for one configurable DMS global hotkey row in the hub.
private struct DMSHotkeySpec {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isEnabled: (DMSConfig) -> Bool
    let key: (DMSConfig) -> String
    let modifiers: (DMSConfig) -> String
    let setEnabled: (inout DMSConfig, Bool) -> Void
    let setKey: (inout DMSConfig, String) -> Void
    let setModifiers: (inout DMSConfig, String) -> Void
    let defaultKey: String
    let defaultModifiers: String
    let trigger: () -> Void
}

/// Class-based holder for the NSEvent local keyDown monitor used by inline recording.
/// (Views are value types, so the escaping monitor closure captures this class instead.)
@MainActor
private final class InlineRecorder: ObservableObject {
    @Published var recordingID: String? = nil
    private var monitor: Any? = nil
    private var onCapture: ((String, String, [String]) -> Void)?

    func toggle(_ id: String, capture: @escaping (String, String, [String]) -> Void) {
        if recordingID == id {
            stop()
        } else {
            start(id, capture: capture)
        }
    }

    func start(_ id: String, capture: @escaping (String, String, [String]) -> Void) {
        stopMonitor()
        onCapture = capture
        recordingID = id
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let activeID = self.recordingID else { return event }
            let mods = Self.modifierTokens(from: event.modifierFlags)
            guard let key = Self.keyToken(from: event) else { return event }
            if key == "escape" && mods.isEmpty {
                self.stop()
                return nil
            }
            self.onCapture?(activeID, key, mods)
            self.stop()
            return nil
        }
    }

    func stop() {
        recordingID = nil
        onCapture = nil
        stopMonitor()
    }

    private func stopMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
        }
        monitor = nil
    }

    private static func modifierTokens(from flags: NSEvent.ModifierFlags) -> [String] {
        var tokens: [String] = []
        if flags.contains(.control) { tokens.append("ctrl") }
        if flags.contains(.option) { tokens.append("alt") }
        if flags.contains(.shift) { tokens.append("shift") }
        if flags.contains(.command) { tokens.append("cmd") }
        return tokens
    }

    private static func keyToken(from event: NSEvent) -> String? {
        switch event.keyCode {
        case 53: return "escape"
        case 36: return "return"
        case 48: return "tab"
        case 49: return "space"
        case 51: return "delete"
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        default: break
        }
        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return nil }
        return chars.lowercased()
    }
}

/// Material 3 Interactive Keybinds Hub: live inline shortcut recording, conflict
/// detection, one-click triggering, and automatic OmniWM keybinds import.
public struct KeybindsView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var configStore = ConfigStore.shared
    @StateObject private var recorder = InlineRecorder()
    @State private var searchText: String = ""
    @State private var selectedChip: String = "All"
    @State private var omniwmEntries: [OmniWMKeybindEntry] = []

    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    // MARK: - DMS hotkey specs

    private var dmsHotkeySpecs: [DMSHotkeySpec] {
        [
            DMSHotkeySpec(
                id: "launcher",
                title: "App Launcher",
                description: "Spotlight-style launcher, math & app search",
                icon: "sparkle.magnifyingglass",
                isEnabled: { $0.launcherHotkey },
                key: { $0.launcherHotkeyKey },
                modifiers: { $0.launcherHotkeyModifiers },
                setEnabled: { $0.launcherHotkey = $1 },
                setKey: { $0.launcherHotkeyKey = $1 },
                setModifiers: { $0.launcherHotkeyModifiers = $1 },
                defaultKey: "space",
                defaultModifiers: "option",
                trigger: { LauncherController.shared.toggle() }
            ),
            DMSHotkeySpec(
                id: "dash",
                title: "DankDash Overview",
                description: "Dashboard HUD with telemetry, calendar & media",
                icon: "gauge",
                isEnabled: { $0.dashHotkey },
                key: { $0.dashHotkeyKey },
                modifiers: { $0.dashHotkeyModifiers },
                setEnabled: { $0.dashHotkey = $1 },
                setKey: { $0.dashHotkeyKey = $1 },
                setModifiers: { $0.dashHotkeyModifiers = $1 },
                defaultKey: "d",
                defaultModifiers: "option",
                trigger: { DashController.shared.toggle() }
            ),
            DMSHotkeySpec(
                id: "notepad",
                title: "Notepad Scratchpad",
                description: "Floating scratchpad notes overlay",
                icon: "note.text",
                isEnabled: { $0.notepadHotkey },
                key: { $0.notepadHotkeyKey },
                modifiers: { $0.notepadHotkeyModifiers },
                setEnabled: { $0.notepadHotkey = $1 },
                setKey: { $0.notepadHotkeyKey = $1 },
                setModifiers: { $0.notepadHotkeyModifiers = $1 },
                defaultKey: "n",
                defaultModifiers: "option",
                trigger: { NotepadController.shared.toggle() }
            ),
            DMSHotkeySpec(
                id: "clipboard",
                title: "Clipboard History",
                description: "Multi-item clipboard history viewer",
                icon: "doc.on.clipboard.fill",
                isEnabled: { $0.clipboardHotkey },
                key: { $0.clipboardHotkeyKey },
                modifiers: { $0.clipboardHotkeyModifiers },
                setEnabled: { $0.clipboardHotkey = $1 },
                setKey: { $0.clipboardHotkeyKey = $1 },
                setModifiers: { $0.clipboardHotkeyModifiers = $1 },
                defaultKey: "v",
                defaultModifiers: "option",
                trigger: { ClipboardController.shared.toggle() }
            ),
            DMSHotkeySpec(
                id: "wallpaperPicker",
                title: "Slanted Wallpaper Picker",
                description: "Slanted slice carousel with desktop preview",
                icon: "photo.stack.fill",
                isEnabled: { $0.wallpaperPickerHotkey },
                key: { $0.wallpaperPickerHotkeyKey },
                modifiers: { $0.wallpaperPickerHotkeyModifiers },
                setEnabled: { $0.wallpaperPickerHotkey = $1 },
                setKey: { $0.wallpaperPickerHotkeyKey = $1 },
                setModifiers: { $0.wallpaperPickerHotkeyModifiers = $1 },
                defaultKey: "w",
                defaultModifiers: "option",
                trigger: { SlantedWallpaperPickerController.shared.triggerShortcut() }
            )
        ]
    }

    // MARK: - Bindings & conflicts

    private var dmsBindings: [DMSHotkeyBinding] {
        let cfg = configStore.config
        return dmsHotkeySpecs.map { spec in
            DMSHotkeyBinding(
                id: spec.id,
                title: spec.title,
                key: spec.key(cfg),
                modifiers: spec.modifiers(cfg)
                    .split(separator: "+")
                    .map { $0.trimmingCharacters(in: .whitespaces) },
                isEnabled: spec.isEnabled(cfg)
            )
        }
    }

    private var conflicts: [KeybindConflict] {
        KeybindConflictDetector.findConflicts(in: dmsBindings)
    }

    private var conflictIDs: Set<String> {
        Set(conflicts.flatMap { $0.bindingIDs })
    }

    // MARK: - Static cheatsheet entries

    private var shortcuts: [ShortcutEntry] {
        [
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

    // MARK: - Filtering

    private var needle: String {
        searchText.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var chips: [String] {
        var result = ["All", "DankMaterialShell"]
        if !omniwmEntries.isEmpty { result.append("OmniWM") }
        result += ["In-Panel", "Navigation", "System"]
        return result
    }

    private func matchesSearch(_ entry: ShortcutEntry) -> Bool {
        guard !needle.isEmpty else { return true }
        return entry.title.lowercased().contains(needle)
            || entry.keys.lowercased().contains(needle)
            || entry.description.lowercased().contains(needle)
            || entry.category.lowercased().contains(needle)
    }

    private func specMatches(_ spec: DMSHotkeySpec) -> Bool {
        guard !needle.isEmpty else { return true }
        let cfg = configStore.config
        return spec.title.lowercased().contains(needle)
            || spec.description.lowercased().contains(needle)
            || spec.key(cfg).lowercased().contains(needle)
            || HotkeyHelper.displayString(key: spec.key(cfg), modifiers: spec.modifiers(cfg)).lowercased().contains(needle)
    }

    private var visibleSpecs: [DMSHotkeySpec] {
        guard selectedChip == "All" || selectedChip == "DankMaterialShell" else { return [] }
        return dmsHotkeySpecs.filter(specMatches)
    }

    private var visibleOmniWM: [OmniWMKeybindEntry] {
        guard selectedChip == "All" || selectedChip == "OmniWM" else { return [] }
        guard !needle.isEmpty else { return omniwmEntries }
        return omniwmEntries.filter {
            $0.action.lowercased().contains(needle)
                || $0.keys.lowercased().contains(needle)
                || $0.category.lowercased().contains(needle)
        }
    }

    private var visibleStatic: [ShortcutEntry] {
        let allowed: Set<String>
        switch selectedChip {
        case "In-Panel": allowed = ["In-Panel Shortcuts"]
        case "Navigation": allowed = ["Navigation & Windows"]
        case "System": allowed = ["System Actions"]
        default: allowed = ["In-Panel Shortcuts", "Navigation & Windows", "System Actions"]
        }
        return shortcuts.filter { allowed.contains($0.category) && matchesSearch($0) }
    }

    // MARK: - OmniWM import

    private func loadOmniWMKeybinds() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/omniwm/settings.toml")
        Task { @MainActor in
            let parsed = await Task.detached(priority: .utility) { () -> [OmniWMKeybindEntry] in
                guard let toml = try? String(contentsOf: url, encoding: .utf8) else { return [] }
                return OmniWMKeybindParser.parse(toml: toml)
            }.value
            omniwmEntries = parsed
        }
    }

    // MARK: - Config mutation + hotkey reload

    private func setEnabled(_ spec: DMSHotkeySpec, _ val: Bool) {
        let old = spec.isEnabled(configStore.config)
        configStore.update { spec.setEnabled(&$0, val) }
        // AppDelegate's config pipeline re-registers all hotkeys; clear the stale ones now.
        if old != val { HotkeyService.shared.unregisterAll() }
    }

    private func resetSpec(_ spec: DMSHotkeySpec) {
        let cfg = configStore.config
        let changed = !spec.isEnabled(cfg)
            || spec.key(cfg) != spec.defaultKey
            || spec.modifiers(cfg) != spec.defaultModifiers
        configStore.update { c in
            spec.setEnabled(&c, true)
            spec.setKey(&c, spec.defaultKey)
            spec.setModifiers(&c, spec.defaultModifiers)
        }
        if changed { HotkeyService.shared.unregisterAll() }
        ToastCenter.shared.show(icon: "arrow.counterclockwise", message: "Reset \(spec.title) to default")
    }

    private func applyRecorded(_ spec: DMSHotkeySpec, key: String, modifiers: [String]) {
        let mods = modifiers.joined(separator: "+")
        let cfg = configStore.config
        let changed = spec.key(cfg) != key || spec.modifiers(cfg) != mods
        configStore.update { c in
            spec.setKey(&c, key)
            spec.setModifiers(&c, mods)
        }
        if changed { HotkeyService.shared.unregisterAll() }
        ToastCenter.shared.show(
            icon: "keyboard",
            message: "\(spec.title): \(HotkeyHelper.displayString(key: key, modifiers: mods))"
        )
    }

    // MARK: - Inline recording (NSEvent local keyDown monitor)

    private func toggleRecording(_ id: String) {
        recorder.toggle(id, capture: handleRecordedCapture)
    }

    private func handleRecordedCapture(_ id: String, key: String, modifiers: [String]) {
        guard let spec = dmsHotkeySpecs.first(where: { $0.id == id }) else { return }
        applyRecorded(spec, key: key, modifiers: modifiers)
    }

    // MARK: - View pieces

    private func sectionHeader(_ title: String, _ p: DMSPalette) -> some View {
        Text(title.uppercased())
            .font(ThemeStore.shared.font(size: 11, weight: .bold))
            .foregroundColor(Color(hex: p.primary.hex))
            .padding(.horizontal, 4)
    }

    private func dmsRow(_ spec: DMSHotkeySpec, p: DMSPalette) -> some View {
        let cfg = configStore.config
        let enabled = spec.isEnabled(cfg)
        let isRecording = recorder.recordingID == spec.id
        let hasConflict = conflictIDs.contains(spec.id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: spec.icon)
                    .font(ThemeStore.shared.font(size: 13, weight: .semibold))
                    .foregroundColor(enabled ? Color(hex: p.primary.hex) : Color(hex: p.outline.hex))
                    .frame(width: 28, height: 28)
                    .background(
                        enabled
                            ? Color(hex: p.primaryContainer.hex).opacity(0.4)
                            : Color(hex: p.surfaceContainerHigh.hex)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(spec.title)
                            .font(ThemeStore.shared.font(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(enabled ? Color(hex: p.onSurface.hex) : Color(hex: p.outline.hex))
                        if hasConflict {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(ThemeStore.shared.font(size: 8))
                                Text("Conflict")
                                    .font(ThemeStore.shared.font(size: 9, weight: .bold))
                            }
                            .foregroundColor(Color(hex: p.onErrorContainer.hex))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: p.errorContainer.hex))
                            .clipShape(Capsule())
                        }
                    }
                    Text(spec.description)
                        .font(ThemeStore.shared.font(size: 10.5))
                        .foregroundColor(Color(hex: p.outline.hex))
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { spec.isEnabled(configStore.config) },
                    set: { setEnabled(spec, $0) }
                ))
                .toggleStyle(.switch)
                .tint(Color(hex: p.primary.hex))
                .labelsHidden()
            }

            HStack(spacing: 6) {
                // Key pill / inline record button
                Button(action: { toggleRecording(spec.id) }) {
                    Text(isRecording
                         ? "Recording…"
                         : (enabled ? HotkeyHelper.displayString(key: spec.key(cfg), modifiers: spec.modifiers(cfg)) : "Disabled"))
                        .font(ThemeStore.shared.font(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            isRecording
                                ? Color(hex: p.errorContainer.hex)
                                : (enabled ? Color(hex: p.primaryContainer.hex) : Color(hex: p.surfaceContainerHigh.hex))
                        )
                        .foregroundColor(
                            isRecording
                                ? Color(hex: p.onErrorContainer.hex)
                                : (enabled ? Color(hex: p.onPrimaryContainer.hex) : Color(hex: p.outline.hex))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Click, then press the new shortcut in place (Esc cancels)")

                // Reset to default
                Button(action: { resetSpec(spec) }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 24, height: 24)
                        .background(Color(hex: p.surfaceContainerHigh.hex))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Reset to default shortcut")

                // One-click trigger
                Button(action: {
                    onClose()
                    spec.trigger()
                }) {
                    Image(systemName: "play.fill")
                        .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: p.primary.hex))
                        .frame(width: 24, height: 24)
                        .background(Color(hex: p.primaryContainer.hex).opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Trigger \(spec.title) now")

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: p.surfaceContainerLow.hex).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    hasConflict ? Color(hex: p.error.hex) : Color(hex: p.outlineVariant.hex).opacity(0.3),
                    lineWidth: hasConflict ? 1.5 : 1
                )
        )
    }

    private func omniWMSection(p: DMSPalette) -> some View {
        let grouped = Dictionary(grouping: visibleOmniWM, by: { $0.category })
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("OmniWM", p)
            ForEach(grouped.keys.sorted(), id: \.self) { cat in
                VStack(alignment: .leading, spacing: 4) {
                    Text(cat.uppercased())
                        .font(ThemeStore.shared.font(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: p.secondary.hex))
                        .padding(.horizontal, 4)
                    VStack(spacing: 4) {
                        ForEach(grouped[cat] ?? []) { entry in
                            HStack {
                                Text(entry.action)
                                    .font(ThemeStore.shared.font(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: p.onSurface.hex))
                                Spacer()
                                Text(entry.keys)
                                    .font(ThemeStore.shared.font(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: p.primary.hex))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: p.primaryContainer.hex))
                                    .cornerRadius(6)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color(hex: p.surfaceContainerLow.hex))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    private func staticRow(_ entry: ShortcutEntry, p: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.title)
                    .font(ThemeStore.shared.font(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                Spacer()
                Text(entry.keys)
                    .font(ThemeStore.shared.font(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: p.primary.hex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: p.primaryContainer.hex))
                    .cornerRadius(6)
            }
            if !entry.description.isEmpty {
                Text(entry.description)
                    .font(ThemeStore.shared.font(size: 11))
                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: p.surfaceContainerLow.hex))
        .cornerRadius(10)
    }

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(ThemeStore.shared.font(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: p.primary.hex))

                Text("Keyboard Shortcuts")
                    .font(ThemeStore.shared.font(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: p.onSurface.hex))

                if !conflicts.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(ThemeStore.shared.font(size: 10))
                        Text("\(conflicts.count) conflict\(conflicts.count == 1 ? "" : "s")")
                            .font(ThemeStore.shared.font(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color(hex: p.onErrorContainer.hex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: p.errorContainer.hex))
                    .clipShape(Capsule())
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(ThemeStore.shared.font(size: 13, weight: .semibold))
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

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(ThemeStore.shared.font(size: 12))
                    .foregroundColor(Color(hex: p.outline.hex))
                TextField("Search shortcuts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(ThemeStore.shared.font(size: 13))
                    .foregroundColor(Color(hex: p.onSurface.hex))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: p.surfaceContainerLow.hex))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chips, id: \.self) { chip in
                        Button(action: { selectedChip = chip }) {
                            Text(chip)
                                .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                                .foregroundColor(
                                    selectedChip == chip
                                        ? Color(hex: p.onPrimaryContainer.hex)
                                        : Color(hex: p.onSurfaceVariant.hex)
                                )
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    selectedChip == chip
                                        ? Color(hex: p.primaryContainer.hex)
                                        : Color(hex: p.surfaceContainerLow.hex)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !visibleSpecs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("DankMaterialShell", p)
                            VStack(spacing: 6) {
                                ForEach(visibleSpecs, id: \.id) { spec in
                                    dmsRow(spec, p: p)
                                }
                            }
                        }
                    }

                    if !visibleOmniWM.isEmpty {
                        omniWMSection(p: p)
                    }

                    let staticCategories = Array(Set(visibleStatic.map { $0.category })).sorted()
                    ForEach(staticCategories, id: \.self) { cat in
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader(cat, p)
                            VStack(spacing: 6) {
                                ForEach(visibleStatic.filter { $0.category == cat }) { entry in
                                    staticRow(entry, p: p)
                                }
                            }
                        }
                    }

                    if visibleSpecs.isEmpty && visibleOmniWM.isEmpty && visibleStatic.isEmpty {
                        Text("No shortcuts match your search.")
                            .font(ThemeStore.shared.font(size: 12))
                            .foregroundColor(Color(hex: p.outline.hex))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 12)
                    }
                }
                .padding(16)
            }

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Footer
            HStack(spacing: 8) {
                Text("\(shortcuts.count + dmsBindings.count + omniwmEntries.count) shortcuts available")
                    .font(ThemeStore.shared.font(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: p.outline.hex))
                Spacer()
                Button(action: {
                    SettingsController.shared.show(tab: "shortcuts")
                    onClose()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(ThemeStore.shared.font(size: 10))
                        Text("Open Shortcuts Settings")
                            .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: p.primary.hex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: p.primaryContainer.hex).opacity(0.4))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Text("• Press Esc to close")
                    .font(ThemeStore.shared.font(size: 11))
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
        .onAppear { loadOmniWMKeybinds() }
        .onDisappear { recorder.stop() }
    }
}
