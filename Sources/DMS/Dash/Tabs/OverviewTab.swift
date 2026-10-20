import SwiftUI
import DMSCore

/// Overview tab displaying the 3-column dashboard grid from DankDash.
public struct OverviewTab: View {
    @ObservedObject var themeStore = ThemeStore.shared

    public init() {}

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left Column: Clock (top) + Hardware Resource Gauges (bottom)
            VStack(spacing: 10) {
                ClockCard()
                    .frame(height: 148)

                HardwareGaugesCard()
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 92)

            // Right Area: Weather & User Tile (top row) atop Calendar & Media (bottom row)
            VStack(spacing: 10) {
                // Top Row: Weather Card (left) and Wide User Info Card (right, spans above Music)
                HStack(spacing: 10) {
                    WeatherOverviewCard()
                        .frame(width: 166)

                    UserInfoCard()
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 84)

                // Bottom Row: Calendar (left) and Media Overview Player (right, beneath User Tile)
                HStack(spacing: 10) {
                    CalendarOverviewCard()
                        .frame(maxWidth: .infinity)

                    MediaOverviewCard()
                        .frame(width: 113)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

