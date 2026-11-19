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
        ControlCenterWidgetConfig(id: "edit", col: 7, row: 7, w: 1, h: 1, small: true),
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

    /// Default middle-grid tiles for the customizable Control Center grid (canonical hardware tiles).
    public static let defaultGridTiles: [ControlCenterWidgetConfig] = ControlCenterUtils.canonicalHardwareTiles
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

    /// Complete 35-shape Google Material 3 Expressive shape catalog.
    public static let expressiveUserShapes: [String] = AvatarShapeGenerator.expressiveShapeNames

    public static let actionIds: [String] = ["settings", "lock", "power"]
    public static let editId: String = "edit"
    public static let buttonIds: [String] = actionIds + [editId]
    public static let optionIds: [String] = ["diskUsage", "brightnessSlider", "idleInhibitor", "user", "battery", "quickTiles"]

    /// Fixed chrome tiles that always live outside the customizable middle grid
    /// (header buttons and full-width sliders).
    public static let fixedChromeIds: Set<String> = ["user", "lock", "power", "settings", "edit", "volumeSlider", "brightnessSlider", "inputVolumeSlider"]

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
            // Slider minimum width is 2, but never wider than the grid itself.
            let clampedW = max(min(2, columns), min(widget.w, columns))
            let clampedH = max(1, min(widget.h, rows))
            return (clampedW, clampedH)
        }
        if widget.id == "quickTiles" {
            let clampedW = max(min(4, columns), min(widget.w, columns))
            return (clampedW, 1)
        }
        let clampedW = max(1, min(widget.w, columns))
        let clampedH = max(1, min(widget.h, rows))
        return (clampedW, clampedH)
    }

    /// Cycles tile span between 1x1, 2x1, and 4x1 (standard) respecting `canShrink` and `clampSize`.
    /// `quickTiles` toggles between full-width (`min(columns, 8)`) and half-width (`min(columns, 4)`).
    public static func nextSpan(for widget: ControlCenterWidgetConfig, columns: Int) -> (w: Int, h: Int) {
        if widget.id == "quickTiles" {
            let targetW = widget.w > 4 ? min(columns, 4) : min(columns, 8)
            return (targetW, 1)
        }
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

    /// The 14 middle-grid-eligible tiles with their canonical spans
    /// (`nightMode`/`darkMode`/`theme` at 2 wide, `quickTiles` at 8 wide, the rest at 4 wide).
    public static let gridCatalogWidgets: [ControlCenterWidgetConfig] = [
        ControlCenterWidgetConfig(id: "wifi", col: 0, row: 0, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "bluetooth", col: 0, row: 1, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "audioOutput", col: 0, row: 2, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "audioInput", col: 0, row: 3, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "battery", col: 0, row: 4, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "diskUsage", col: 0, row: 5, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "colorPicker", col: 0, row: 6, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "idleInhibitor", col: 0, row: 7, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "doNotDisturb", col: 0, row: 8, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "nightMode", col: 0, row: 9, w: 2, h: 1),
        ControlCenterWidgetConfig(id: "darkMode", col: 0, row: 10, w: 2, h: 1),
        ControlCenterWidgetConfig(id: "theme", col: 0, row: 11, w: 2, h: 1),
        ControlCenterWidgetConfig(id: "media", col: 0, row: 12, w: 4, h: 1),
        ControlCenterWidgetConfig(id: "quickTiles", col: 0, row: 13, w: 8, h: 1)
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

    /// Normalizes a widget list into a valid middle-grid tile set: filters out fixed chrome
    /// and disabled tiles, normalizes legacy aliases (`network` -> `wifi`, `caffeine` ->
    /// `idleInhibitor`, `audioDevice` -> `audioOutput`), deduplicates by `id` (keeping the
    /// first occurrence), and clamps each tile's size. Unlike the legacy `hardwareTiles`,
    /// this preserves `doNotDisturb`, `nightMode`, `darkMode`, `theme`, `media`, and
    /// `quickTiles`, and allows an empty result without falling back to `canonicalHardwareTiles`.
    public static func normalizedGridTiles(from widgets: [ControlCenterWidgetConfig], columns: Int = CcMetrics.defaultColumns) -> [ControlCenterWidgetConfig] {
        var seen: Set<String> = []
        var result: [ControlCenterWidgetConfig] = []
        for var widget in widgets {
            if fixedChromeIds.contains(widget.id) || !widget.enabled { continue }
            // Normalize aliases
            if widget.id == "network" {
                widget.id = "wifi"
            } else if widget.id == "caffeine" {
                widget.id = "idleInhibitor"
            } else if widget.id == "audioDevice" {
                widget.id = "audioOutput"
            }
            if seen.contains(widget.id) { continue }
            seen.insert(widget.id)
            let (w, h) = clampSize(widget: widget, columns: columns)
            widget.w = w
            widget.h = h
            widget.small = (w == 1)
            result.append(widget)
        }
        return result
    }

    /// Extracts and normalizes hardware tiles for the 2D grid, filtering out permanent header and slider widgets.
    public static func hardwareTiles(from widgets: [ControlCenterWidgetConfig]) -> [ControlCenterWidgetConfig] {
        return normalizedGridTiles(from: widgets)
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
        let percent = (total.isFinite && total > 0) ? (used / total) : 0.0
        // Int(Double) traps on NaN/Infinity/overflow; guard and clamp the percentage first.
        let percentInt = percent.isFinite ? Int(round(min(max(percent, 0.0), 1.0) * 100.0)) : 0
        let summary = String(format: "%.1fG / %.1fG (%d%%)", used, total, percentInt)
        let usedStr = String(format: "%.1fG", used)
        let totalStr = String(format: "%.1fG", total)
        return (summary, usedStr, totalStr, percent)
    }
}

/// Grid layout planner for the customizable Control Center middle grid.
/// Normalizes tiles via `ControlCenterUtils.normalizedGridTiles` and packs them with
/// `GridPackingSolver.packCards` (`step: 1.0`, gravity on) to produce collision-free layouts.
public enum ControlCenterGridPlanner: Sendable {

    /// Packs normalized widgets, clamping each widget's `col` to `0...max(0, columns - w)`
    /// and `row` to `max(0, row)`.
    public static func layoutResult(
        for widgets: [ControlCenterWidgetConfig],
        columns: Int,
        width: Double,
        gap: Double = Double(CcMetrics.gridGap),
        rowUnit: Double = Double(CcMetrics.tileHeight)
    ) -> GridPackingSolver.LayoutResult {
        let normalized = ControlCenterUtils.normalizedGridTiles(from: widgets, columns: columns)
        return pack(normalized, columns: columns, width: width, gap: gap, rowUnit: rowUnit)
    }

    /// Moves a tile to `(toCol, toRow)`. Pass 1 packs the remaining tiles so the vacated
    /// slot closes up; pass 2 places the moved tile first at the requested slot so colliding
    /// neighbors settle cleanly downward.
    public static func move(
        widgetID: String,
        toCol: Int,
        toRow: Int,
        in widgets: [ControlCenterWidgetConfig],
        columns: Int,
        width: Double,
        gap: Double = Double(CcMetrics.gridGap),
        rowUnit: Double = Double(CcMetrics.tileHeight)
    ) -> [ControlCenterWidgetConfig] {
        let normalized = ControlCenterUtils.normalizedGridTiles(from: widgets, columns: columns)
        guard let movedIndex = normalized.firstIndex(where: { $0.id == widgetID }) else {
            return normalizeLayout(widgets, columns: columns, width: width, gap: gap, rowUnit: rowUnit)
        }
        let moved = normalized[movedIndex]
        let others = normalized.enumerated().filter { $0.offset != movedIndex }.map(\.element)

        // Pass 1: close up the vacated slot.
        let pass1 = pack(others, columns: columns, width: width, gap: gap, rowUnit: rowUnit)
        let compactedOthers = sync(others, with: pass1)

        // Pass 2: place the moved tile first at the requested slot.
        var movedTile = moved
        movedTile.col = max(0, min(max(0, columns - movedTile.w), toCol))
        movedTile.row = max(0, toRow)
        let pass2Widgets = [movedTile] + compactedOthers
        let pass2 = pack(pass2Widgets, columns: columns, width: width, gap: gap, rowUnit: rowUnit)
        return sync(pass2Widgets, with: pass2)
    }

    /// Inserts a new tile into the earliest open slot found by `GridPackingSolver.firstFit`.
    public static func insert(
        _ tile: ControlCenterWidgetConfig,
        into widgets: [ControlCenterWidgetConfig],
        columns: Int,
        width: Double,
        gap: Double = Double(CcMetrics.gridGap),
        rowUnit: Double = Double(CcMetrics.tileHeight)
    ) -> [ControlCenterWidgetConfig] {
        let normalized = ControlCenterUtils.normalizedGridTiles(from: widgets, columns: columns)
        var newTile = tile
        if newTile.id == "network" {
            newTile.id = "wifi"
        } else if newTile.id == "caffeine" {
            newTile.id = "idleInhibitor"
        } else if newTile.id == "audioDevice" {
            newTile.id = "audioOutput"
        }
        if ControlCenterUtils.fixedChromeIds.contains(newTile.id)
            || normalized.contains(where: { $0.id == newTile.id }) {
            return normalizeLayout(widgets, columns: columns, width: width, gap: gap, rowUnit: rowUnit)
        }
        let (w, h) = ControlCenterUtils.clampSize(widget: newTile, columns: columns)
        newTile.w = w
        newTile.h = h
        newTile.small = (w == 1)
        newTile.enabled = true

        // Existing tiles keep their fixed (col, row); the new tile gets nil so firstFit finds the earliest open slot.
        let existingCards = normalized.map { card(for: $0, columns: columns) }
        let newCard = GridPackingSolver.CardItem(id: newTile.id, col: nil, row: nil, w: Double(w), h: Double(h), small: newTile.small)
        let result = GridPackingSolver.packCards(cards: existingCards + [newCard], columns: columns, width: width, gap: gap, rowUnit: rowUnit, step: 1.0, gravity: true)
        return sync(normalized + [newTile], with: result)
    }

    /// Cycles a tile's span via `ControlCenterUtils.nextSpan`, repacking with the resized
    /// tile first (others in `(row, col)` order) so neighbors settle cleanly.
    public static func cycleSpan(
        widgetID: String,
        in widgets: [ControlCenterWidgetConfig],
        columns: Int,
        width: Double,
        gap: Double = Double(CcMetrics.gridGap),
        rowUnit: Double = Double(CcMetrics.tileHeight)
    ) -> [ControlCenterWidgetConfig] {
        let normalized = ControlCenterUtils.normalizedGridTiles(from: widgets, columns: columns)
        guard let index = normalized.firstIndex(where: { $0.id == widgetID }) else {
            return normalizeLayout(widgets, columns: columns, width: width, gap: gap, rowUnit: rowUnit)
        }
        var resized = normalized[index]
        let (newW, newH) = ControlCenterUtils.nextSpan(for: resized, columns: columns)
        resized.col = max(0, min(resized.col, max(0, columns - newW)))
        resized.w = newW
        resized.h = newH
        resized.small = (newW == 1)
        let others = normalized.enumerated()
            .filter { $0.offset != index }
            .map(\.element)
            .sorted { ($0.row, $0.col) < ($1.row, $1.col) }
        let ordered = [resized] + others
        let result = pack(ordered, columns: columns, width: width, gap: gap, rowUnit: rowUnit)
        return sync(ordered, with: result)
    }

    /// Packs normalized widgets with `step: 1.0, gravity: true`, syncs `(col, row)` from the
    /// layout result, and sorts by `(row, col)`.
    public static func normalizeLayout(
        _ widgets: [ControlCenterWidgetConfig],
        columns: Int,
        width: Double,
        gap: Double = Double(CcMetrics.gridGap),
        rowUnit: Double = Double(CcMetrics.tileHeight)
    ) -> [ControlCenterWidgetConfig] {
        let normalized = ControlCenterUtils.normalizedGridTiles(from: widgets, columns: columns)
        let result = pack(normalized, columns: columns, width: width, gap: gap, rowUnit: rowUnit)
        return sync(normalized, with: result)
    }

    // MARK: - Helpers

    private static func card(for widget: ControlCenterWidgetConfig, columns: Int) -> GridPackingSolver.CardItem {
        let clampedCol = max(0, min(max(0, columns - widget.w), widget.col))
        return GridPackingSolver.CardItem(
            id: widget.id,
            col: Double(clampedCol),
            row: Double(max(0, widget.row)),
            w: Double(widget.w),
            h: Double(widget.h),
            small: widget.small
        )
    }

    private static func pack(
        _ widgets: [ControlCenterWidgetConfig],
        columns: Int,
        width: Double,
        gap: Double,
        rowUnit: Double
    ) -> GridPackingSolver.LayoutResult {
        let cards = widgets.map { card(for: $0, columns: columns) }
        return GridPackingSolver.packCards(cards: cards, columns: columns, width: width, gap: gap, rowUnit: rowUnit, step: 1.0, gravity: true)
    }

    private static func sync(_ widgets: [ControlCenterWidgetConfig], with result: GridPackingSolver.LayoutResult) -> [ControlCenterWidgetConfig] {
        var slotsById: [String: GridPackingSolver.GridSlot] = [:]
        for slot in result.slots {
            slotsById[slot.id] = slot
        }
        return widgets.map { widget in
            var updated = widget
            if let slot = slotsById[widget.id] {
                updated.col = Int(slot.col.rounded())
                updated.row = Int(slot.row.rounded())
            }
            return updated
        }.sorted { lhs, rhs in
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.col < rhs.col
        }
    }
}
