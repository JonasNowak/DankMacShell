import SwiftUI
import DMSCore

/// Compact weather overview card matching DankDash design.
public struct WeatherOverviewCard: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var weather = WeatherService.shared
    @ObservedObject var controller = DashController.shared

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let current = weather.currentWeather
        let isCelsius = ConfigStore.shared.config.weatherUnits.lowercased() == "celsius"
        let tempStr = isCelsius ? "\(Int(round(current.temperatureC)))°C" : "\(Int(round(current.temperatureF)))°F"

        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                controller.activeTab = .weather
            }
        }) {
            HStack(spacing: 10) {
                // Weather Condition Icon on the left
                Image(systemName: current.sfSymbol)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(Color(hex: p.primary.hex))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 32, height: 32)

                // Temperature and Condition description stacked on the right
                VStack(alignment: .leading, spacing: 1) {
                    Text(tempStr)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                        .lineLimit(1)

                    Text(current.conditionDescription.isEmpty ? "Clear" : current.conditionDescription)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color(hex: p.surfaceContainerHigh.hex))
            .cornerRadius(12)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }


        .buttonStyle(.plain)
    }

    private var displayLocation: String {
        let raw = weather.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return "Current Location"
        }
        // If string is long (e.g. "San Francisco, United States"), extract city name to fit perfectly without "..."
        if raw.count > 18, let city = raw.split(separator: ",").first {
            return String(city).trimmingCharacters(in: .whitespaces)
        }
        return raw
    }
}
