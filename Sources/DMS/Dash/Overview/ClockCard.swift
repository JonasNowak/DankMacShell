import SwiftUI
import Combine
import DMSCore

/// Stacked large-digit clock card matching DankDash design.
public struct ClockCard: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let is24h = ConfigStore.shared.config.getSetting("timeFormat")?.stringValue == "24h"
        let hourStr = formatDigits(currentTime, format: is24h ? "HH" : "hh")
        let minStr = formatDigits(currentTime, format: "mm")
        let dateStr = formatDate(currentTime)

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

        .onReceive(timer) { input in
            currentTime = input
        }
    }

    private func formatDigits(_ date: Date, format: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = format
        return fmt.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
}
