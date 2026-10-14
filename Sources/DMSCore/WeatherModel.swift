import Foundation

/// Current weather telemetry and condition info.
public struct WeatherData: Sendable, Codable, Equatable {
    public var temperatureC: Double
    public var apparentTemperatureC: Double
    public var weatherCode: Int
    public var humidity: Int
    public var windSpeedKmh: Double
    public var isDay: Bool
    public var locationName: String
    public var updatedAt: Date

    public var temperatureF: Double {
        (temperatureC * 9.0 / 5.0) + 32.0
    }

    public var conditionDescription: String {
        switch weatherCode {
        case 0:
            return "Clear Sky"
        case 1:
            return "Mainly Clear"
        case 2:
            return "Partly Cloudy"
        case 3:
            return "Overcast"
        case 45, 48:
            return "Fog"
        case 51, 53, 55:
            return "Drizzle"
        case 61, 63, 65:
            return "Rain"
        case 66, 67:
            return "Freezing Rain"
        case 71, 73, 75:
            return "Snow Fall"
        case 77:
            return "Snow Grains"
        case 80, 81, 82:
            return "Rain Showers"
        case 85, 86:
            return "Snow Showers"
        case 95:
            return "Thunderstorm"
        case 96, 99:
            return "Thunderstorm with Hail"
        default:
            return "Fair"
        }
    }

    public var sfSymbol: String {
        switch weatherCode {
        case 0:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 61, 63:
            return "cloud.drizzle.fill"
        case 65, 80, 81, 82:
            return "cloud.heavyrain.fill"
        case 66, 67:
            return "cloud.sleet.fill"
        case 71, 73, 75, 77, 85, 86:
            return "snowflake"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return isDay ? "sun.max.fill" : "moon.fill"
        }
    }

    public init(
        temperatureC: Double = 20.0,
        apparentTemperatureC: Double = 20.0,
        weatherCode: Int = 0,
        humidity: Int = 50,
        windSpeedKmh: Double = 10.0,
        isDay: Bool = true,
        locationName: String = "Local",
        updatedAt: Date = Date()
    ) {
        self.temperatureC = temperatureC
        self.apparentTemperatureC = apparentTemperatureC
        self.weatherCode = weatherCode
        self.humidity = humidity
        self.windSpeedKmh = windSpeedKmh
        self.isDay = isDay
        self.locationName = locationName
        self.updatedAt = updatedAt
    }
}
