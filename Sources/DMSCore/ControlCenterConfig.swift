import Foundation

/// Per-tile configuration for the Control Center 2D grid.
public struct ControlCenterWidgetConfig: Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var col: Int
    public var row: Int
    public var w: Int
    public var h: Int
    public var small: Bool
    public var enabled: Bool
    public var options: [String: AnyCodable]

    public init(
        id: String,
        col: Int = 0,
        row: Int = 0,
        w: Int = 4,
        h: Int = 1,
        small: Bool = false,
        enabled: Bool = true,
        options: [String: AnyCodable] = [:]
    ) {
        self.id = id
        self.col = col
        self.row = row
        self.w = w
        self.h = h
        self.small = small
        self.enabled = enabled
        self.options = options
    }

    public static let defaultWidgets: [ControlCenterWidgetConfig] = [
        ControlCenterWidgetConfig(id: "user", col: 0, row: 0, w: 5, h: 1),
        ControlCenterWidgetConfig(id: "lock", col: 5, row: 0, w: 1, h: 1, small: true),
        ControlCenterWidgetConfig(id: "power", col: 6, row: 0, w: 1, h: 1, small: true),
        ControlCenterWidgetConfig(id: "settings", col: 7, row: 0, w: 1, h: 1, small: true),
        ControlCenterWidgetConfig(id: "edit", col: 7, row: 0, w: 1, h: 1, small: true),
        ControlCenterWidgetConfig(id: "volumeSlider", col: 0, row: 1, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "brightnessSlider", col: 4, row: 1, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "wifi", col: 0, row: 2, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "bluetooth", col: 4, row: 2, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "audioOutput", col: 0, row: 3, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "audioInput", col: 4, row: 3, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "battery", col: 0, row: 4, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "diskUsage", col: 4, row: 4, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "colorPicker", col: 0, row: 5, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "idleInhibitor", col: 4, row: 5, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "doNotDisturb", col: 0, row: 6, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "nightMode", col: 4, row: 6, w: 2, h: 1),
        ControlCenterWidgetConfig(id: "darkMode", col: 6, row: 6, w: 2, h: 1)
    ]
}

/// 50-step undo/redo stack recording Control Center grid snapshots.
public final class ControlCenterUndoStack: @unchecked Sendable {
    public struct Snapshot: Sendable, Equatable {
        public var widgets: [ControlCenterWidgetConfig]
        public var columns: Int

        public init(widgets: [ControlCenterWidgetConfig], columns: Int) {
            self.widgets = widgets
            self.columns = columns
        }
    }

    private let lock = NSLock()
    private var undoHistory: [Snapshot] = []
    private var redoHistory: [Snapshot] = []
    public let maxCapacity: Int

    public init(initialWidgets: [ControlCenterWidgetConfig] = [], initialColumns: Int = 8, maxCapacity: Int = 50) {
        self.maxCapacity = max(1, maxCapacity)
        if !initialWidgets.isEmpty {
            self.undoHistory.append(Snapshot(widgets: initialWidgets, columns: initialColumns))
        }
    }

    public var canUndo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return undoHistory.count > 1
    }

    public var canRedo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !redoHistory.isEmpty
    }

    public func record(widgets: [ControlCenterWidgetConfig], columns: Int) {
        lock.lock()
        defer { lock.unlock() }
        let snapshot = Snapshot(widgets: widgets, columns: columns)
        if let last = undoHistory.last, last == snapshot {
            return
        }
        undoHistory.append(snapshot)
        if undoHistory.count > maxCapacity {
            undoHistory.removeFirst(undoHistory.count - maxCapacity)
        }
        redoHistory.removeAll()
    }

    public func undo() -> Snapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard undoHistory.count > 1 else { return nil }
        let current = undoHistory.removeLast()
        redoHistory.append(current)
        return undoHistory.last
    }

    public func redo() -> Snapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard !redoHistory.isEmpty else { return nil }
        let next = redoHistory.removeLast()
        undoHistory.append(next)
        return next
    }

    public func reset(widgets: [ControlCenterWidgetConfig], columns: Int) {
        lock.lock()
        defer { lock.unlock() }
        undoHistory = [Snapshot(widgets: widgets, columns: columns)]
        redoHistory.removeAll()
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        undoHistory.removeAll()
        redoHistory.removeAll()
    }
}

/// Control Center widget catalog, sizing, and helper utilities.
/// Ported 1:1 from upstream DMS `quickshell/Modules/ControlCenter/utils/widgets.js`.
public enum ControlCenterUtils: Sendable {
    public static let userShapes: [String] = [
        "circle", "cookie4", "cookie7", "cookie12", "clover4", "clover8",
        "sunny", "pentagon", "arch", "slanted", "gem", "square"
    ]

    public static let actionIds: [String] = ["settings", "lock", "power"]
    public static let editId: String = "edit"
    public static let buttonIds: [String] = actionIds + [editId]
    public static let optionIds: [String] = ["diskUsage", "brightnessSlider", "idleInhibitor", "user", "battery", "quickTiles"]

    public static func nextUserShape(_ current: String) -> String {
        guard let idx = userShapes.firstIndex(of: current) else {
            return userShapes[0]
        }
        return userShapes[(idx + 1) % userShapes.count]
    }

    public static func isSliderWidget(_ id: String) -> Bool {
        return id == "volumeSlider" || id == "brightnessSlider" || id == "inputVolumeSlider"
    }

    public static func canShrink(_ id: String) -> Bool {
        return id != "user" && !isSliderWidget(id)
    }

    public static func isRemovable(_ widget: ControlCenterWidgetConfig) -> Bool {
        return widget.id != editId
    }

    public static func ensureEditButton(widgets: [ControlCenterWidgetConfig]) -> [ControlCenterWidgetConfig] {
        if widgets.contains(where: { $0.id == editId }) {
            return widgets
        }
        var updated = widgets
        updated.append(ControlCenterWidgetConfig(id: editId, col: 7, row: 0, w: 1, h: 1, small: true))
        return updated
    }

    public static func clampSize(widget: ControlCenterWidgetConfig, columns: Int, rows: Int = 100) -> (w: Int, h: Int) {
        if widget.id == "user" {
            let userW = max(1, columns - actionIds.count)
            return (userW, 1)
        }
        if buttonIds.contains(widget.id) {
            return (1, 1)
        }
        if isSliderWidget(widget.id) {
            let clampedW = max(2, min(widget.w, columns))
            let clampedH = max(1, min(widget.h, rows))
            return (clampedW, clampedH)
        }
        let clampedW = max(1, min(widget.w, columns))
        let clampedH = max(1, min(widget.h, rows))
        return (clampedW, clampedH)
    }

    /// Cycles tile span between 1x1, 2x1, and 4x1 (standard) respecting `canShrink` and `clampSize`.
    public static func nextSpan(for widget: ControlCenterWidgetConfig, columns: Int) -> (w: Int, h: Int) {
        guard canShrink(widget.id) else {
            return clampSize(widget: widget, columns: columns)
        }
        let targetW: Int
        if widget.w >= 4 {
            targetW = 2
        } else if widget.w == 2 {
            targetW = 1
        } else {
            targetW = 4
        }
        var nextWidget = widget
        nextWidget.w = targetW
        nextWidget.h = 1
        nextWidget.small = (targetW == 1)
        return clampSize(widget: nextWidget, columns: columns)
    }

    /// Complete registry of all known widgets for the Tile Library.
    public static let catalogWidgets: [ControlCenterWidgetConfig] = [
        ControlCenterWidgetConfig(id: "wifi", col: 0, row: 0, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "bluetooth", col: 4, row: 0, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "audioOutput", col: 0, row: 1, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "audioInput", col: 4, row: 1, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "battery", col: 0, row: 2, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "diskUsage", col: 4, row: 2, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "colorPicker", col: 0, row: 3, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "idleInhibitor", col: 4, row: 3, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "doNotDisturb", col: 0, row: 4, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "nightMode", col: 4, row: 4, w: 2, h: 1),
        ControlCenterWidgetConfig(id: "darkMode", col: 6, row: 4, w: 2, h: 1),
        ControlCenterWidgetConfig(id: "theme", col: 0, row: 5, w: 2, h: 1),
        ControlCenterWidgetConfig(id: "media", col: 0, row: 6, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "quickTiles", col: 0, row: 7, w: 8, h: 1),
        ControlCenterWidgetConfig(id: "volumeSlider", col: 0, row: 8, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "brightnessSlider", col: 4, row: 8, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "lock", col: 5, row: 0, w: 1, h: 1, small: true),
        ControlCenterWidgetConfig(id: "power", col: 6, row: 0, w: 1, h: 1, small: true),
        ControlCenterWidgetConfig(id: "settings", col: 7, row: 0, w: 1, h: 1, small: true)
    ]

    /// Canonical 8 hardware tiles in the 2-column grid matching cc.png 1:1.
    public static let canonicalHardwareTiles: [ControlCenterWidgetConfig] = [
        ControlCenterWidgetConfig(id: "wifi", col: 0, row: 0, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "bluetooth", col: 4, row: 0, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "audioOutput", col: 0, row: 1, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "audioInput", col: 4, row: 1, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "battery", col: 0, row: 2, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "diskUsage", col: 4, row: 2, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "colorPicker", col: 0, row: 3, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "idleInhibitor", col: 4, row: 3, w: 4, h: 1)
    ]

    /// Extracts and normalizes hardware tiles for the 2D grid, filtering out permanent header and slider widgets.
    public static func hardwareTiles(from widgets: [ControlCenterWidgetConfig]) -> [ControlCenterWidgetConfig] {
        let excluded: Set<String> = ["user", "lock", "power", "settings", "edit", "volumeSlider", "brightnessSlider", "doNotDisturb", "nightMode", "darkMode", "theme"]
        var filtered = widgets.filter { !excluded.contains($0.id) && $0.enabled }
        // If empty or only contains partial/corrupt legacy data missing core hardware tiles, restore canonical 8 tiles
        if filtered.isEmpty || (!filtered.contains(where: { $0.id == "audioOutput" || $0.id == "audioDevice" }) && !filtered.contains(where: { $0.id == "colorPicker" })) {
            return canonicalHardwareTiles
        }
        // Normalize aliases
        for i in 0..<filtered.count {
            if filtered[i].id == "network" {
                filtered[i].id = "wifi"
            } else if filtered[i].id == "caffeine" {
                filtered[i].id = "idleInhibitor"
            } else if filtered[i].id == "audioDevice" {
                filtered[i].id = "audioOutput"
            }
        }
        return filtered
    }

    public static func title(for id: String) -> String {
        switch id {
        case "wifi": return "Wi-Fi"
        case "bluetooth": return "Bluetooth"
        case "audioOutput": return "Audio Output"
        case "audioInput": return "Audio Input"
        case "battery": return "Battery"
        case "diskUsage": return "Storage"
        case "colorPicker": return "Color Picker"
        case "idleInhibitor": return "Keep Awake"
        case "doNotDisturb": return "Do Not Disturb"
        case "nightMode": return "Night Shift"
        case "darkMode": return "Dark Mode"
        case "theme": return "Theme"
        case "media": return "Now Playing"
        case "quickTiles": return "Quick Actions"
        case "volumeSlider": return "Volume Slider"
        case "brightnessSlider": return "Brightness Slider"
        case "lock": return "Lock Display"
        case "power": return "Power Menu"
        case "settings": return "Settings"
        case "user": return "User Profile"
        case "edit": return "Edit Layout"
        default: return id.capitalized
        }
    }

    public static func subtitle(for id: String) -> String {
        switch id {
        case "wifi": return "Network connection & SSID"
        case "bluetooth": return "Paired devices & discovery"
        case "audioOutput": return "Speaker & volume level"
        case "audioInput": return "Microphone & input level"
        case "battery": return "Charge level & power source"
        case "diskUsage": return "Available system drive space"
        case "colorPicker": return "Screen color eyedropper"
        case "idleInhibitor": return "Prevent system & display sleep"
        case "doNotDisturb": return "Silence alerts & notifications"
        case "nightMode": return "Display color temperature"
        case "darkMode": return "Switch light & dark appearance"
        case "theme": return "Cycle Material 3 palettes"
        case "media": return "Active media playback controls"
        case "quickTiles": return "Compact toggles bundle"
        case "volumeSlider": return "Full-width master volume slider"
        case "brightnessSlider": return "Full-width screen brightness slider"
        case "lock": return "Sleep display immediately"
        case "power": return "Lock, sleep, restart, shut down"
        case "settings": return "Configure DMS preferences"
        default: return "Control Center quick tile"
        }
    }

    public static func icon(for id: String) -> String {
        switch id {
        case "wifi": return "wifi"
        case "bluetooth": return "antenna.radiowaves.left.and.right"
        case "audioOutput": return "speaker.wave.2.fill"
        case "audioInput": return "mic.fill"
        case "battery": return "bolt.batteryblock.fill"
        case "diskUsage": return "internaldrive"
        case "colorPicker": return "paintpalette.fill"
        case "idleInhibitor": return "cup.and.saucer.fill"
        case "doNotDisturb": return "bell.slash"
        case "nightMode": return "sun.max.trianglebadge.exclamationmark"
        case "darkMode": return "moon"
        case "theme": return "circle.lefthalf.filled"
        case "media": return "play.circle.fill"
        case "quickTiles": return "square.grid.2x2.fill"
        case "volumeSlider": return "speaker.wave.3.fill"
        case "brightnessSlider": return "sun.max"
        case "lock": return "lock"
        case "power": return "power"
        case "settings": return "gearshape"
        case "user": return "person.crop.circle"
        case "edit": return "pencil"
        default: return "square.grid.2x2"
        }
    }

    public static func category(for id: String) -> String {
        switch id {
        case "wifi", "bluetooth": return "Connectivity"
        case "audioOutput", "audioInput", "volumeSlider", "brightnessSlider", "media": return "Audio & Display"
        case "battery", "diskUsage": return "System"
        case "colorPicker", "idleInhibitor", "doNotDisturb", "quickTiles": return "Utilities"
        case "nightMode", "darkMode", "theme": return "Appearance"
        default: return "General"
        }
    }

    public static func formatStorage(usedBytes: Int64, totalBytes: Int64) -> (summary: String, usedGB: String, totalGB: String, rawPercent: Double) {
        let used = Double(usedBytes) / (1024.0 * 1024.0 * 1024.0)
        let total = Double(totalBytes) / (1024.0 * 1024.0 * 1024.0)
        let percent = total > 0 ? (used / total) : 0.0
        let percentInt = Int(round(percent * 100.0))
        let summary = String(format: "%.1fG / %.1fG (%d%%)", used, total, percentInt)
        let usedStr = String(format: "%.1fG", used)
        let totalStr = String(format: "%.1fG", total)
        return (summary, usedStr, totalStr, percent)
    }
}
