import Foundation
import DMSCore

/// Fetches and caches live weather telemetry via Open-Meteo REST API.
@MainActor
public final class WeatherService: ObservableObject {
    public static let shared = WeatherService()

    @Published public private(set) var currentWeather: WeatherData = WeatherData()
    private var lastFetchTime: Date?

    private init() {
        fetchWeather()
        // Refresh every 15 minutes
        Timer.scheduledTimer(withTimeInterval: 900.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchWeather()
            }
        }
    }

    public func fetchWeather(force: Bool = false) {
        if !force, let last = lastFetchTime, Date().timeIntervalSince(last) < 600 {
            return
        }

        let lat = 52.5200 // Default latitude
        let lon = 13.4050 // Default longitude
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m"

        guard let url = URL(string: urlString) else { return }

        Task.detached {
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }

            struct OpenMeteoResponse: Codable {
                struct Current: Codable {
                    let temperature_2m: Double
                    let relative_humidity_2m: Int
                    let apparent_temperature: Double
                    let is_day: Int
                    let weather_code: Int
                    let wind_speed_10m: Double
                }
                let current: Current
            }

            guard let decoded = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else {
                return
            }

            let weather = WeatherData(
                temperatureC: decoded.current.temperature_2m,
                apparentTemperatureC: decoded.current.apparent_temperature,
                weatherCode: decoded.current.weather_code,
                humidity: decoded.current.relative_humidity_2m,
                windSpeedKmh: decoded.current.wind_speed_10m,
                isDay: decoded.current.is_day == 1,
                locationName: "Local",
                updatedAt: Date()
            )

            await MainActor.run {
                WeatherService.shared.currentWeather = weather
                WeatherService.shared.lastFetchTime = Date()
            }
        }
    }
}
