import Foundation
import CoreGraphics

/// Control Center dimensional metrics singleton.
/// Ported 1:1 from upstream `quickshell/Modules/ControlCenter/CcMetrics.qml`.
public enum CcMetrics: Sendable {
    public static let defaultColumns: Int = 8
    public static let minimumColumns: Int = 6
    public static let maximumColumns: Int = 12

    public static let defaultSheetWidth: CGFloat = 394.0
    public static let defaultSheetHeight: CGFloat = 348.0

    public static let sheetPadding: CGFloat = 12.0
    public static let tileHeight: CGFloat = 44.0
    public static let columnWidth: CGFloat = tileHeight // 44.0
    public static let gridGap: CGFloat = 6.0
    public static let gridStep: Double = 0.5

    public static let detailHeightList: CGFloat = 235.0
    public static let detailHeightBrightness: CGFloat = 268.0
    public static let detailHeightDefault: CGFloat = 175.0

    /// Total sheet width for a given number of columns.
    /// width = sheetPadding * 2 + columns * columnWidth + (columns - 1) * gridGap
    public static func sheetWidthFor(columns: Int) -> CGFloat {
        let cols = CGFloat(clampColumns(columns))
        return sheetPadding * 2.0 + cols * columnWidth + (cols - 1.0) * gridGap
    }

    public static func clampColumns(_ value: Int) -> Int {
        return max(minimumColumns, min(maximumColumns, value))
    }

    public static func columnCapFor(availableWidth: CGFloat) -> Int {
        return max(1, Int(floor((availableWidth - sheetPadding * 2.0 + gridGap) / (columnWidth + gridGap))))
    }

    public static func rowCapFor(availableHeight: CGFloat, cellHeight: CGFloat = tileHeight) -> Int {
        return max(1, Int(floor((availableHeight + gridGap) / (cellHeight + gridGap))))
    }

    public static func preferredDetailHeight(section: String) -> CGFloat {
        if section.isEmpty { return 0 }
        if section.hasPrefix("brightnessSlider") {
            return detailHeightBrightness
        }
        switch section {
        case "wifi", "network", "bluetooth", "battery", "builtin_vpn", "builtin_tailscale",
             "audioOutput", "audioInput", "diskUsage", "runningApps":
            return detailHeightList
        default:
            return detailHeightDefault
        }
    }
}
