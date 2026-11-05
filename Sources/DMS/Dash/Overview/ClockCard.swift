import SwiftUI
import Combine
import DMSCore

/// Stacked large-digit clock card matching DankDash design.
public struct ClockCard: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject private var clock = ClockService.shared

    private static let hour24Formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH"
        return f
    }()
    private static let hour12Formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh"
        return f
    }()
    private static let minFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "mm"
        return f
    }()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let currentTime = clock.currentDate
        let is24h = ConfigStore.shared.config.getSetting("timeFormat")?.stringValue == "24h"
        let hourStr = (is24h ? Self.hour24Formatter : Self.hour12Formatter).string(from: currentTime)
        let minStr = Self.minFormatter.string(from: currentTime)
        let dateStr = Self.dateFormatter.string(from: currentTime)

        VStack(alignment: .center, spacing: 0) {
            Text(hourStr)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: p.primary.hex))
                .lineLimit(1)

            Text(minStr)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: p.primary.hex))
                .lineLimit(1)

            Spacer()

            Text(dateStr)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(hex: p.surfaceContainerHigh.hex))
        .cornerRadius(12)
    }
}
