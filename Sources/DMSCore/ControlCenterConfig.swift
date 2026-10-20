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
