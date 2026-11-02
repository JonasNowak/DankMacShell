import Testing
import Foundation
@testable import DMSCore

@Suite("Weather Forecast, Dew Point, and Celestial Engine Tests")
struct WeatherTests {

    @Test("Cardinal Wind Direction Calculation")
    func testCardinalWindDirection() {
        #expect(WeatherData.cardinalDirection(from: 0.0) == "N")
        #expect(WeatherData.cardinalDirection(from: 360.0) == "N")
        #expect(WeatherData.cardinalDirection(from: 45.0) == "NE")
        #expect(WeatherData.cardinalDirection(from: 90.0) == "E")
        #expect(WeatherData.cardinalDirection(from: 135.0) == "SE")
        #expect(WeatherData.cardinalDirection(from: 180.0) == "S")
        #expect(WeatherData.cardinalDirection(from: 225.0) == "SW")
        #expect(WeatherData.cardinalDirection(from: 270.0) == "W")
        #expect(WeatherData.cardinalDirection(from: 315.0) == "NW")
        #expect(WeatherData.cardinalDirection(from: -45.0) == "NW")
    }

    @Test("Magnus-Tetens Dew Point Approximation")
    func testDewPointCalculation() {
        // At 20°C and 50% relative humidity, dew point is approximately 9.3°C
        let dp = WeatherData.calculateDewPoint(tempC: 20.0, humidity: 50)
        #expect(abs(dp - 9.3) < 0.5)

        // At 100% relative humidity, dew point equals the temperature
        let dp100 = WeatherData.calculateDewPoint(tempC: 25.0, humidity: 100)
        #expect(abs(dp100 - 25.0) < 0.1)

        // Property accessors on WeatherData
        let weather = WeatherData(temperatureC: 20.0, humidity: 50)
        #expect(abs(weather.dewPointC - 9.3) < 0.5)
        #expect(weather.dewPointF > 45.0 && weather.dewPointF < 52.0)
    }

    @Test("UV Index Severity Categorization")
    func testUVSeverityClassification() {
        #expect(WeatherData.uvSeverityLabel(for: 0.0) == "Low")
        #expect(WeatherData.uvSeverityLabel(for: 2.9) == "Low")
        #expect(WeatherData.uvSeverityLabel(for: 3.0) == "Moderate")
        #expect(WeatherData.uvSeverityLabel(for: 5.9) == "Moderate")
        #expect(WeatherData.uvSeverityLabel(for: 6.0) == "High")
        #expect(WeatherData.uvSeverityLabel(for: 7.9) == "High")
        #expect(WeatherData.uvSeverityLabel(for: 8.0) == "Very High")
        #expect(WeatherData.uvSeverityLabel(for: 10.9) == "Very High")
        #expect(WeatherData.uvSeverityLabel(for: 11.0) == "Extreme")
        #expect(WeatherData.uvSeverityLabel(for: 15.0) == "Extreme")
    }

    @Test("HourlyForecastPoint and DailyForecastPoint Models")
    func testForecastPoints() {
        let now = Date()
        let hourly = HourlyForecastPoint(
            time: now,
            hourLabel: "Now",
            temperatureC: 15.0,
            precipitationProbability: 35,
            weatherCode: 61,
            isDay: true
        )

        #expect(hourly.hourLabel == "Now")
        #expect(hourly.temperatureC == 15.0)
        #expect(hourly.temperatureF == 59.0)
        #expect(hourly.precipitationProbability == 35)
        #expect(hourly.sfSymbol == "cloud.drizzle.fill")

        let daily = DailyForecastPoint(
            date: now,
            weatherCode: 0,
            tempMaxC: 22.0,
            tempMinC: 12.0,
            precipitationProbabilityMax: 10,
            uvIndexMax: 4.5,
            sunrise: now,
            sunset: now.addingTimeInterval(36000)
        )

        #expect(daily.tempMaxC == 22.0)
        #expect(daily.tempMinC == 12.0)
        #expect(daily.tempMaxF == 71.6)
        #expect(daily.tempMinF == 53.6)
        #expect(daily.uvIndexMax == 4.5)
        #expect(daily.sfSymbol == "sun.max.fill")
    }

    @Test("CelestialEngine Day Progress with Sunrise and Sunset")
    func testCelestialEngineDayProgress() {
        let calendar = Calendar.current
        let today = Date()
        let sunrise = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: today)!
        let sunset = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: today)!

        // Noon (12:00) should be halfway through the day (progress = 0.5)
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today)!
        let noonProgress = CelestialEngine.dayProgress(now: noon, sunrise: sunrise, sunset: sunset)
        #expect(abs(noonProgress - 0.5) < 0.01)
        #expect(CelestialEngine.isDay(now: noon, sunrise: sunrise, sunset: sunset) == true)

        // Sunrise (06:00) progress = 0.0
        let atRise = CelestialEngine.dayProgress(now: sunrise, sunrise: sunrise, sunset: sunset)
        #expect(abs(atRise - 0.0) < 0.01)

        // Sunset (18:00) progress = 1.0
        let atSet = CelestialEngine.dayProgress(now: sunset, sunrise: sunrise, sunset: sunset)
        #expect(abs(atSet - 1.0) < 0.01)

        // Midnight is outside day hours
        let midnight = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: today)!
        #expect(CelestialEngine.isDay(now: midnight, sunrise: sunrise, sunset: sunset) == false)
    }
}
