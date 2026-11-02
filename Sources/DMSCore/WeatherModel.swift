import Foundation

/// A single hourly forecast point for 24-hour weather prediction charts.
public struct HourlyForecastPoint: Sendable, Codable, Equatable, Identifiable {
    public var id: Date { time }
    public var time: Date
    public var hourLabel: String
    public var temperatureC: Double
    public var precipitationProbability: Int
    public var weatherCode: Int
    public var isDay: Bool

    public var temperatureF: Double {
        (temperatureC * 9.0 / 5.0) + 32.0
    }

    public var sfSymbol: String {
        WeatherData.symbolFor(weatherCode: weatherCode, isDay: isDay)
    }

    public init(
        time: Date,
        hourLabel: String,
        temperatureC: Double,
        precipitationProbability: Int = 0,
        weatherCode: Int = 0,
        isDay: Bool = true
    ) {
        self.time = time
        self.hourLabel = hourLabel
        self.temperatureC = temperatureC
        self.precipitationProbability = max(0, min(100, precipitationProbability))
        self.weatherCode = weatherCode
        self.isDay = isDay
    }
}

/// A daily forecast point for 7-day weather outlooks.
public struct DailyForecastPoint: Sendable, Codable, Equatable, Identifiable {
    public var id: Date { date }
    public var date: Date
    public var weatherCode: Int
    public var tempMaxC: Double
    public var tempMinC: Double
    public var precipitationProbabilityMax: Int
    public var uvIndexMax: Double
    public var sunrise: Date?
    public var sunset: Date?

    public var tempMaxF: Double {
        (tempMaxC * 9.0 / 5.0) + 32.0
    }

    public var tempMinF: Double {
        (tempMinC * 9.0 / 5.0) + 32.0
    }

    public var sfSymbol: String {
        WeatherData.symbolFor(weatherCode: weatherCode, isDay: true)
    }

    public init(
        date: Date,
        weatherCode: Int,
        tempMaxC: Double,
        tempMinC: Double,
        precipitationProbabilityMax: Int = 0,
        uvIndexMax: Double = 0.0,
        sunrise: Date? = nil,
        sunset: Date? = nil
    ) {
        self.date = date
        self.weatherCode = weatherCode
        self.tempMaxC = tempMaxC
        self.tempMinC = tempMinC
        self.precipitationProbabilityMax = max(0, min(100, precipitationProbabilityMax))
        self.uvIndexMax = uvIndexMax
        self.sunrise = sunrise
        self.sunset = sunset
    }
}

/// Current weather telemetry and condition info.
public struct WeatherData: Sendable, Codable, Equatable {
    public var temperatureC: Double
    public var apparentTemperatureC: Double
    public var weatherCode: Int
    public var humidity: Int
    public var windSpeedKmh: Double
    public var windDirectionDegrees: Double
    public var surfacePressureHpa: Double
    public var uvIndex: Double
    public var isDay: Bool
    public var locationName: String
    public var sunrise: Date?
    public var sunset: Date?
    public var hourlyForecast: [HourlyForecastPoint]
    public var dailyForecast: [DailyForecastPoint]
    public var updatedAt: Date

    public var temperatureF: Double {
        (temperatureC * 9.0 / 5.0) + 32.0
    }

    public var apparentTemperatureF: Double {
        (apparentTemperatureC * 9.0 / 5.0) + 32.0
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
        Self.symbolFor(weatherCode: weatherCode, isDay: isDay)
    }

    public static func symbolFor(weatherCode: Int, isDay: Bool) -> String {
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

    /// 16-point compass cardinal direction string from degrees (0...360).
    public var cardinalWindDirection: String {
        Self.cardinalDirection(from: windDirectionDegrees)
    }

    public static func cardinalDirection(from degrees: Double) -> String {
        let cardinals = [
            "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
            "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"
        ]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let idx = Int(round(normalized / 22.5)) % 16
        return cardinals[idx]
    }

    /// Dew point calculation in Celsius using the Magnus-Tetens approximation formula.
    public var dewPointC: Double {
        Self.calculateDewPoint(tempC: temperatureC, humidity: humidity)
    }

    public var dewPointF: Double {
        (dewPointC * 9.0 / 5.0) + 32.0
    }

    public static func calculateDewPoint(tempC: Double, humidity: Int) -> Double {
        let a = 17.27
        let b = 237.7
        let rh = max(1.0, min(100.0, Double(humidity)))
        let alpha = ((a * tempC) / (b + tempC)) + log(rh / 100.0)
        return (b * alpha) / (a - alpha)
    }

    /// UV Index severity descriptor per World Health Organization guidelines.
    public var uvSeverity: String {
        Self.uvSeverityLabel(for: uvIndex)
    }

    public static func uvSeverityLabel(for uv: Double) -> String {
        switch uv {
        case ..<3.0:
            return "Low"
        case 3.0..<6.0:
            return "Moderate"
        case 6.0..<8.0:
            return "High"
        case 8.0..<11.0:
            return "Very High"
        default:
            return "Extreme"
        }
    }

    public init(
        temperatureC: Double = 20.0,
        apparentTemperatureC: Double = 20.0,
        weatherCode: Int = 0,
        humidity: Int = 50,
        windSpeedKmh: Double = 10.0,
        windDirectionDegrees: Double = 0.0,
        surfacePressureHpa: Double = 1013.25,
        uvIndex: Double = 0.0,
        isDay: Bool = true,
        locationName: String = "Local",
        sunrise: Date? = nil,
        sunset: Date? = nil,
        hourlyForecast: [HourlyForecastPoint] = [],
        dailyForecast: [DailyForecastPoint] = [],
        updatedAt: Date = Date()
    ) {
        self.temperatureC = temperatureC
        self.apparentTemperatureC = apparentTemperatureC
        self.weatherCode = weatherCode
        self.humidity = humidity
        self.windSpeedKmh = windSpeedKmh
        self.windDirectionDegrees = windDirectionDegrees
        self.surfacePressureHpa = surfacePressureHpa
        self.uvIndex = uvIndex
        self.isDay = isDay
        self.locationName = locationName
        self.sunrise = sunrise
        self.sunset = sunset
        self.hourlyForecast = hourlyForecast
        self.dailyForecast = dailyForecast
        self.updatedAt = updatedAt
    }
}
