import SwiftUI
import DMSCore

/// Comprehensive weather dashboard view featuring celestial sky arc, 24h curve, and sensor metrics.
public struct WeatherTab: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var weatherService = WeatherService.shared

    let hourlyForecast: [(hour: String, temp: Int, icon: String)] = [
        ("Now", 54, "sun.max.fill"),
        ("3 PM", 56, "sun.max.fill"),
        ("4 PM", 55, "cloud.sun.fill"),
        ("5 PM", 52, "cloud.sun.fill"),
        ("6 PM", 49, "sunset.fill"),
        ("7 PM", 46, "moon.stars.fill"),
        ("8 PM", 44, "moon.fill"),
        ("9 PM", 43, "moon.fill")
    ]

    @ObservedObject var configStore = ConfigStore.shared
    @State private var locationInput: String = ""
    @State private var isEditingLocation: Bool = false

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let current = weatherService.currentWeather
        let moon = CelestialEngine.moonPhase(date: Date())
        let isCelsius = configStore.config.weatherUnits.lowercased() == "celsius"

        VStack(spacing: 8) {
            // Top Row: Weather Hero & Celestial Sky Arc
            HStack(spacing: 8) {
                // Weather Hero Card
                VStack(alignment: .leading, spacing: 6) {
                    // Location Header & Quick Change Button
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: p.primary.hex))

                        Text(weatherService.locationName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: p.onSurface.hex))
                            .lineLimit(1)

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditingLocation.toggle()
                                if isEditingLocation {
                                    locationInput = configStore.config.weatherLocation
                                }
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: isEditingLocation ? "xmark" : "magnifyingglass")
                                Text(isEditingLocation ? "Cancel" : "Change")
                            }
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: p.primary.hex))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color(hex: p.primaryContainer.hex).opacity(0.6))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if isEditingLocation {
                        HStack(spacing: 5) {
                            TextField("City or coordinates", text: $locationInput, onCommit: {
                                commitLocation()
                            })
                            .textFieldStyle(.plain)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: p.surfaceContainerLow.hex))
                            .cornerRadius(5)

                            Button(action: commitLocation) {
                                if weatherService.isFetching {
                                    ProgressView()
                                        .scaleEffect(0.4)
                                        .frame(width: 12, height: 12)
                                } else {
                                    Text("Set")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color(hex: p.primary.hex))
                                        .foregroundColor(Color(hex: p.onPrimary.hex))
                                        .cornerRadius(5)
                                }
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                locationInput = "auto"
                                commitLocation()
                            }) {
                                Text("Auto")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: p.surfaceContainerHighest.hex))
                                    .foregroundColor(Color(hex: p.onSurface.hex))
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: current.sfSymbol)
                                .font(.system(size: 34))
                                .foregroundColor(Color(hex: p.primary.hex))
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 1) {
                                let tempStr = isCelsius ? "\(Int(round(current.temperatureC)))°C" : "\(Int(round(current.temperatureF)))°F"
                                let feelsStr = isCelsius ? "\(Int(round(current.apparentTemperatureC)))°C" : "\(Int(round(current.apparentTemperatureC * 9 / 5 + 32)))°F"

                                Text(tempStr)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: p.onSurface.hex))

                                HStack(spacing: 4) {
                                    Text(current.conditionDescription)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                                        .lineLimit(1)

                                    Text("• Feels \(feelsStr)")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: p.outline.hex))
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: p.surfaceContainerHigh.hex))
                .cornerRadius(16)

                // Celestial Sky Arc (WeatherSky)
                VStack(spacing: 4) {
                    HStack {
                        Label("Solar Trajectory", systemImage: "sun.max")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        Spacer()
                        Label(moon.name, systemImage: moon.sfSymbol)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: p.primary.hex))
                    }

                    // Parabolic Celestial Arc
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let progress = 0.62 // Mid-afternoon sun

                        ZStack {
                            // Horizon line
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: h - 6))
                                path.addLine(to: CGPoint(x: w, y: h - 6))
                            }
                            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                            // Parabolic Arc
                            Path { path in
                                path.move(to: CGPoint(x: 8, y: h - 6))
                                path.addQuadCurve(
                                    to: CGPoint(x: w - 8, y: h - 6),
                                    control: CGPoint(x: w / 2.0, y: 8)
                                )
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: p.primary.hex).opacity(0.3), Color(hex: p.primary.hex), Color(hex: p.primary.hex).opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2.0
                            )

                            // Sun Orb on the arc
                            let sunX = 8 + (w - 16) * CGFloat(progress)
                            let normX = CGFloat(progress)
                            let sunY = (h - 6) - CGFloat(CelestialEngine.parabolicHeight(progress: Double(normX))) * (h - 16)

                            ZStack {
                                Circle()
                                    .fill(Color(hex: p.primary.hex).opacity(0.3))
                                    .frame(width: 18, height: 18)
                                Circle()
                                    .fill(Color(hex: p.primary.hex))
                                    .frame(width: 10, height: 10)
                            }
                            .position(x: sunX, y: sunY)
                        }
                    }
                    .frame(height: 44)

                    HStack {
                        Text("Sunrise 6:32 AM")
                        Spacer()
                        Text("Sunset 6:18 PM")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: p.outline.hex))
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: p.surfaceContainerHigh.hex))
                .cornerRadius(16)
            }
            .frame(height: 102)

            // Middle Row: 24-Hour Hourly Forecast
            VStack(alignment: .leading, spacing: 6) {
                Text("24-Hour Forecast")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: p.onSurface.hex))

                HStack(spacing: 0) {
                    ForEach(0..<hourlyForecast.count, id: \.self) { idx in
                        let item = hourlyForecast[idx]
                        VStack(spacing: 4) {
                            Text(item.hour)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: p.onSurfaceVariant.hex))

                            Image(systemName: item.icon)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: p.primary.hex))

                            Text("\(item.temp)°")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: p.onSurface.hex))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: p.surfaceContainerHigh.hex))
            .cornerRadius(14)
            .frame(height: 74)

            // Bottom Row: Sensor Metrics Cards
            HStack(spacing: 8) {
                MetricSensorTile(
                    title: "Wind",
                    value: "\(Int(round(current.windSpeedKmh))) km/h",
                    subtext: "NW • Moderate",
                    icon: "wind",
                    palette: p
                )
                MetricSensorTile(
                    title: "Humidity",
                    value: "\(current.humidity)%",
                    subtext: "Dew point 42°",
                    icon: "humidity.fill",
                    palette: p
                )
                MetricSensorTile(
                    title: "UV Index",
                    value: "3",
                    subtext: "Moderate",
                    icon: "sun.badge.exclamationmark",
                    palette: p
                )
                MetricSensorTile(
                    title: "Air Pressure",
                    value: "1018 hPa",
                    subtext: "Stable",
                    icon: "barometer",
                    palette: p
                )
            }
            .frame(height: 72)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commitLocation() {
        let trimmed = locationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        weatherService.setManualLocation(trimmed)
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingLocation = false
        }
    }
}

private struct MetricSensorTile: View {
    let title: String
    let value: String
    let subtext: String
    let icon: String
    let palette: DMSPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: palette.primary.hex))
            }
            Spacer()
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: palette.onSurface.hex))
            Text(subtext)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: palette.outline.hex))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: palette.surfaceContainerHigh.hex))
        .cornerRadius(18)
    }
}
