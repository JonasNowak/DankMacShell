import SwiftUI
import DMSCore

/// Comprehensive weather dashboard view featuring celestial sky arc, live 24h curve, and sensor metrics.
public struct WeatherTab: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var weatherService = WeatherService.shared
    @ObservedObject var configStore = ConfigStore.shared

    @State private var locationInput: String = ""
    @State private var isEditingLocation: Bool = false

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "h:mm a"
        return df
    }()

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let current = weatherService.currentWeather
        let moon = CelestialEngine.moonPhase(date: Date())
        let isCelsius = configStore.config.weatherUnits.lowercased() == "celsius"

        // Celestial sunrise / sunset calculation
        let now = Date()
        let sunrise = current.sunrise ?? Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: now) ?? now
        let sunset = current.sunset ?? Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: now) ?? now
        let isDayTime = CelestialEngine.isDay(now: now, sunrise: sunrise, sunset: sunset)
        let dayProgress = CelestialEngine.dayProgress(now: now, sunrise: sunrise, sunset: sunset)

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
                                let feelsStr = isCelsius ? "\(Int(round(current.apparentTemperatureC)))°C" : "\(Int(round(current.apparentTemperatureF)))°F"

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
                        Label("Solar Trajectory", systemImage: isDayTime ? "sun.max" : "moon.stars")
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

                        ZStack {
                            // Horizon line
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: h - 6))
                                path.addLine(to: CGPoint(x: w, y: h - 6))
                            }
                            .stroke(themeStore.subtleTrackColor, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

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

                            // Sun / Moon Orb on the arc
                            let orbProgress = isDayTime ? dayProgress : 0.5
                            let orbX = 8 + (w - 16) * CGFloat(orbProgress)
                            let orbY = (h - 6) - CGFloat(CelestialEngine.parabolicHeight(progress: orbProgress)) * (h - 16)

                            ZStack {
                                Circle()
                                    .fill(Color(hex: p.primary.hex).opacity(0.3))
                                    .frame(width: 18, height: 18)
                                Circle()
                                    .fill(isDayTime ? Color(hex: p.primary.hex) : Color(hex: p.tertiary.hex))
                                    .frame(width: 10, height: 10)
                            }
                            .position(x: orbX, y: orbY)
                        }
                    }
                    .frame(height: 44)

                    HStack {
                        Text("Sunrise \(Self.timeFormatter.string(from: sunrise))")
                        Spacer()
                        Text("Sunset \(Self.timeFormatter.string(from: sunset))")
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

            // Middle Row: 24-Hour Hourly Forecast Chart
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("24-Hour Forecast")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                    Spacer()
                    if let first = current.hourlyForecast.first {
                        Text("Rain chance: \(first.precipitationProbability)%")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    }
                }

                WeatherForecastChart(
                    points: current.hourlyForecast,
                    isCelsius: isCelsius,
                    palette: p
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(hex: p.surfaceContainerHigh.hex))
            .cornerRadius(14)
            .frame(height: 98)

            // Bottom Row: Live Sensor Metrics Cards
            HStack(spacing: 8) {
                MetricSensorTile(
                    title: "Wind",
                    value: "\(Int(round(current.windSpeedKmh))) km/h",
                    subtext: "\(current.cardinalWindDirection) • Moderate",
                    icon: "wind",
                    palette: p
                )
                let dewStr = isCelsius ? "\(Int(round(current.dewPointC)))°C" : "\(Int(round(current.dewPointF)))°F"
                MetricSensorTile(
                    title: "Humidity",
                    value: "\(current.humidity)%",
                    subtext: "Dew point \(dewStr)",
                    icon: "humidity.fill",
                    palette: p
                )
                MetricSensorTile(
                    title: "UV Index",
                    value: "\(Int(round(current.uvIndex)))",
                    subtext: current.uvSeverity,
                    icon: "sun.badge.exclamationmark",
                    palette: p
                )
                MetricSensorTile(
                    title: "Air Pressure",
                    value: "\(Int(round(current.surfacePressureHpa))) hPa",
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

/// Smooth cubic Bezier forecast temperature curve with precipitation indicators and hour labels.
public struct WeatherForecastChart: View {
    public let points: [HourlyForecastPoint]
    public let isCelsius: Bool
    public let palette: DMSPalette

    public init(points: [HourlyForecastPoint], isCelsius: Bool, palette: DMSPalette) {
        self.points = points
        self.isCelsius = isCelsius
        self.palette = palette
    }

    public var body: some View {
        let displayPoints: [HourlyForecastPoint] = points.isEmpty ? fallbackPoints : Array(points.prefix(24))

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(displayPoints) { pt in
                    VStack(spacing: 2) {
                        Text(pt.hourLabel)
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

                        Image(systemName: pt.sfSymbol)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: palette.primary.hex))

                        let tempVal = isCelsius ? Int(round(pt.temperatureC)) : Int(round(pt.temperatureF))
                        Text("\(tempVal)°")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: palette.onSurface.hex))

                        if pt.precipitationProbability > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 7))
                                    .foregroundColor(Color(hex: palette.tertiary.hex))
                                Text("\(pt.precipitationProbability)%")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(Color(hex: palette.tertiary.hex))
                            }
                        } else {
                            Spacer()
                                .frame(height: 10)
                        }
                    }
                    .frame(width: 38)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var fallbackPoints: [HourlyForecastPoint] {
        let now = Date()
        return [
            HourlyForecastPoint(time: now, hourLabel: "Now", temperatureC: 20, precipitationProbability: 0, weatherCode: 0, isDay: true),
            HourlyForecastPoint(time: now.addingTimeInterval(3600), hourLabel: "1 PM", temperatureC: 21, precipitationProbability: 5, weatherCode: 1, isDay: true),
            HourlyForecastPoint(time: now.addingTimeInterval(7200), hourLabel: "2 PM", temperatureC: 22, precipitationProbability: 10, weatherCode: 2, isDay: true),
            HourlyForecastPoint(time: now.addingTimeInterval(10800), hourLabel: "3 PM", temperatureC: 21, precipitationProbability: 15, weatherCode: 3, isDay: true),
            HourlyForecastPoint(time: now.addingTimeInterval(14400), hourLabel: "4 PM", temperatureC: 19, precipitationProbability: 25, weatherCode: 61, isDay: true),
            HourlyForecastPoint(time: now.addingTimeInterval(18000), hourLabel: "5 PM", temperatureC: 18, precipitationProbability: 30, weatherCode: 61, isDay: true),
            HourlyForecastPoint(time: now.addingTimeInterval(21600), hourLabel: "6 PM", temperatureC: 16, precipitationProbability: 10, weatherCode: 2, isDay: false),
            HourlyForecastPoint(time: now.addingTimeInterval(25200), hourLabel: "7 PM", temperatureC: 15, precipitationProbability: 0, weatherCode: 0, isDay: false)
        ]
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
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: palette.onSurface.hex))
            Text(subtext)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: palette.outline.hex))
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: palette.surfaceContainerHigh.hex))
        .cornerRadius(14)
    }
}
