import SwiftUI
import AppKit
import DMSCore

/// Compact Digital Wellbeing overview card for the DankDash Overview tab.
public struct WellbeingOverviewCard: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var wellbeingService = WellbeingService.shared
    @ObservedObject var controller = DashController.shared

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let todayKey = WellbeingFormatter.dateKey(for: Date())
        let topApps = wellbeingService.store.topApps(for: todayKey, limit: 3)
        let totalSecs = wellbeingService.todayTotalSeconds

        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                controller.activeTab = .wellbeing
            }
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: p.primary.hex))

                    Text("Digital Wellbeing")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurface.hex))

                    Spacer()

                    Text(WellbeingFormatter.formatDuration(seconds: totalSecs))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: p.primary.hex))
                }

                // Mini app usage breakdown
                if topApps.isEmpty {
                    Text("No focus activity recorded yet")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: p.outline.hex))
                        .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(spacing: 4) {
                        ForEach(topApps) { app in
                            HStack(spacing: 6) {
                                Text(app.appName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                                    .lineLimit(1)

                                Spacer()

                                let ratio = totalSecs > 0 ? (app.durationSeconds / totalSecs) : 0
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(themeStore.subtleTrackColor)
                                        Capsule()
                                            .fill(Color(hex: p.primary.hex))
                                            .frame(width: geo.size.width * CGFloat(ratio))
                                    }
                                }
                                .frame(width: 48, height: 4)

                                Text(WellbeingFormatter.formatDuration(seconds: app.durationSeconds))
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundColor(Color(hex: p.outline.hex))
                                    .frame(width: 32, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: p.surfaceContainerHigh.hex))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}
