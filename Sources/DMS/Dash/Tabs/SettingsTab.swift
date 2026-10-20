import SwiftUI
import DMSCore

/// Quick settings configuration tab for DankDash.
public struct SettingsTab: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var weatherService = WeatherService.shared
    @ObservedObject var configStore = ConfigStore.shared
    @State private var timeFormat24h: Bool = false
    @State private var manualLocationInput: String = ""
    @State private var defaultTab: DashTab = .overview

    let themeOptions = ["purple", "blue", "green", "orange", "red", "yellow"]

    public init() {}

    public var body: some View {
        let p = themeStore.palette

        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                // Theme Palettes Card
                VStack(alignment: .leading, spacing: 14) {
                    Label("Theme & Appearance", systemImage: "paintpalette.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: p.onSurface.hex))

                    HStack(spacing: 12) {
                        ForEach(themeOptions, id: \.self) { tName in
                            Button(action: {
                                themeStore.apply(theme: tName)
                            }) {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(themeColor(for: tName))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: themeStore.themeName == tName ? 2.5 : 0)
                                        )

                                    Text(tName.capitalized)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(hex: p.onSurface.hex))
                                }
                                .padding(8)
                                .background(themeStore.themeName == tName ? Color(hex: p.surfaceVariant.hex) : Color.clear)
                                .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                        }

                        // Dynamic Wallpaper Theme
                        Button(action: {
                            themeStore.setDynamicWallpaper()
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 16))
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: p.primaryContainer.hex))
                                    .foregroundColor(Color(hex: p.primary.hex))
                                    .clipShape(Circle())

                                Text("Dynamic")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(hex: p.onSurface.hex))
                            }
                            .padding(8)
                            .background(themeStore.themeName == "dynamic" ? Color(hex: p.surfaceVariant.hex) : Color.clear)
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // Dark / Light Mode Toggle
                    Toggle(isOn: Binding(
                        get: { !themeStore.isLightMode },
                        set: { themeStore.setLightMode(!$0) }
                    )) {
                        HStack {
                            Image(systemName: themeStore.isLightMode ? "sun.max.fill" : "moon.stars.fill")
                                .foregroundColor(Color(hex: p.primary.hex))
                            Text("Dark Surface Mode")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: p.onSurface.hex))
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding(18)
                .background(Color(hex: p.surfaceContainerHigh.hex))
                .cornerRadius(22)

                // Units & Formats Card
                VStack(alignment: .leading, spacing: 14) {
                    Label("Clock & Meteorological Units", systemImage: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: p.onSurface.hex))

                    Toggle(isOn: $timeFormat24h) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(Color(hex: p.primary.hex))
                            Text("Use 24-Hour Digital Clock Format")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: p.onSurface.hex))
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()
                        .background(Color.white.opacity(0.1))

                    Toggle(isOn: Binding(
                        get: { configStore.config.weatherUnits.lowercased() == "celsius" },
                        set: { val in
                            configStore.update { $0.weatherUnits = val ? "celsius" : "fahrenheit" }
                        }
                    )) {
                        HStack {
                            Image(systemName: "thermometer")
                                .foregroundColor(Color(hex: p.primary.hex))
                            Text("Display Temperature in Celsius (°C)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: p.onSurface.hex))
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // Weather Location Input
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(Color(hex: p.primary.hex))
                            Text("Weather Location")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: p.onSurface.hex))
                        }

                        HStack(spacing: 8) {
                            TextField("City name, lat,lon, or 'auto' (e.g. London, 40.71,-74.00, auto)", text: $manualLocationInput, onCommit: {
                                updateWeatherLocation()
                            })
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color(hex: p.surfaceVariant.hex))
                            .cornerRadius(8)

                            Button("Update") {
                                updateWeatherLocation()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color(hex: p.primary.hex))
                            .foregroundColor(Color(hex: p.onPrimary.hex))
                            .cornerRadius(8)

                            Button("Auto") {
                                manualLocationInput = "auto"
                                updateWeatherLocation()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(hex: p.surfaceVariant.hex))
                            .cornerRadius(8)
                        }

                        Text("Current: \(weatherService.locationName) (\(String(format: "%.2f", weatherService.latitude)), \(String(format: "%.2f", weatherService.longitude)))")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: p.outline.hex))
                    }
                }
                .padding(18)
                .background(Color(hex: p.surfaceContainerHigh.hex))
                .cornerRadius(22)
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            manualLocationInput = configStore.config.weatherLocation
        }
    }

    private func updateWeatherLocation() {
        let trimmed = manualLocationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        weatherService.setManualLocation(trimmed)
    }

    private func themeColor(for name: String) -> Color {
        switch name {
        case "purple": return Color(hex: "#b895ff")
        case "blue": return Color(hex: "#90caf9")
        case "green": return Color(hex: "#81c784")
        case "orange": return Color(hex: "#ffb74d")
        case "red": return Color(hex: "#e57373")
        case "yellow": return Color(hex: "#fff176")
        default: return Color(hex: "#b895ff")
        }
    }
}
