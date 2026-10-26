import Testing
import Foundation
@testable import DMSCore

@Suite("Telemetry Formatting, Thermals, and Timed Inhibit Tests")
struct TelemetryAndPopoutTests {

    // MARK: - 1. Network Throughput Formatting

    @Test("Network Throughput Standard Formatting")
    func testNetworkThroughputFormatting() {
        #expect(SystemTelemetry.formatByteRate(0) == "0 B/s")
        #expect(SystemTelemetry.formatByteRate(-10) == "0 B/s")
        #expect(SystemTelemetry.formatByteRate(512) == "512 B/s")
        #expect(SystemTelemetry.formatByteRate(1023) == "1023 B/s")

        // KB/s
        #expect(SystemTelemetry.formatByteRate(1024) == "1.0 KB/s")
        #expect(SystemTelemetry.formatByteRate(1536) == "1.5 KB/s")
        #expect(SystemTelemetry.formatByteRate(99.4 * 1024) == "99.4 KB/s")
        #expect(SystemTelemetry.formatByteRate(100 * 1024) == "100 KB/s")
        #expect(SystemTelemetry.formatByteRate(500 * 1024) == "500 KB/s")

        // MB/s
        #expect(SystemTelemetry.formatByteRate(1024 * 1024) == "1.0 MB/s")
        #expect(SystemTelemetry.formatByteRate(12.5 * 1024 * 1024) == "12.5 MB/s")
        #expect(SystemTelemetry.formatByteRate(150 * 1024 * 1024) == "150 MB/s")

        // GB/s
        #expect(SystemTelemetry.formatByteRate(1024 * 1024 * 1024) == "1.00 GB/s")
        #expect(SystemTelemetry.formatByteRate(2.45 * 1024 * 1024 * 1024) == "2.45 GB/s")
    }

    @Test("Network Throughput Compact Formatting")
    func testNetworkThroughputCompactFormatting() {
        #expect(SystemTelemetry.formatCompactByteRate(0) == "0B")
        #expect(SystemTelemetry.formatCompactByteRate(750) == "750B")
        #expect(SystemTelemetry.formatCompactByteRate(1536) == "1.5K")
        #expect(SystemTelemetry.formatCompactByteRate(15 * 1024) == "15K")
        #expect(SystemTelemetry.formatCompactByteRate(2.4 * 1024 * 1024) == "2.4M")
        #expect(SystemTelemetry.formatCompactByteRate(50 * 1024 * 1024) == "50M")
        #expect(SystemTelemetry.formatCompactByteRate(1.8 * 1024 * 1024 * 1024) == "1.8G")
    }

    // MARK: - 2. Temperature Conversion & M3 Severity Thresholds

    @Test("Temperature Unit Conversion")
    func testTemperatureUnitConversion() {
        let celsius = TemperatureUnit.celsius
        let fahrenheit = TemperatureUnit.fahrenheit

        #expect(celsius.convert(celsius: 0.0) == 0.0)
        #expect(celsius.convert(celsius: 100.0) == 100.0)

        #expect(fahrenheit.convert(celsius: 0.0) == 32.0)
        #expect(abs(fahrenheit.convert(celsius: 25.0) - 77.0) < 0.001)
        #expect(abs(fahrenheit.convert(celsius: 100.0) - 212.0) < 0.001)

        #expect(celsius.symbol == "°C")
        #expect(fahrenheit.symbol == "°F")

        #expect(SystemTelemetry.formatTemperature(25.0, unit: .celsius) == "25°C")
        #expect(SystemTelemetry.formatTemperature(25.0, unit: .fahrenheit) == "77°F")
    }

    @Test("Thermal Severity M3 Thresholds")
    func testThermalSeverityThresholds() {
        // Normal: < 70°C
        #expect(SystemTelemetry.thermalSeverity(forCelsius: 25.0) == .normal)
        #expect(SystemTelemetry.thermalSeverity(forCelsius: 45.0) == .normal)
        #expect(SystemTelemetry.thermalSeverity(forCelsius: 69.9) == .normal)

        // Warning: 70°C – 85°C
        #expect(SystemTelemetry.thermalSeverity(forCelsius: 70.0) == .warning)
        #expect(SystemTelemetry.thermalSeverity(forCelsius: 78.5) == .warning)
        #expect(SystemTelemetry.thermalSeverity(forCelsius: 85.0) == .warning)

        // Critical: > 85°C
        #expect(SystemTelemetry.thermalSeverity(forCelsius: 85.1) == .critical)
        #expect(SystemTelemetry.thermalSeverity(forCelsius: 95.0) == .critical)
        #expect(SystemTelemetry.thermalSeverity(forCelsius: 105.0) == .critical)
    }

    // MARK: - 3. Timed Idle Inhibit Presets & Expiration Logic

    @Test("Idle Inhibit Presets Duration Seconds")
    func testIdleInhibitPresets() {
        #expect(IdleInhibitPreset.m15.durationSeconds == 900.0)
        #expect(IdleInhibitPreset.m30.durationSeconds == 1800.0)
        #expect(IdleInhibitPreset.h1.durationSeconds == 3600.0)
        #expect(IdleInhibitPreset.h2.durationSeconds == 7200.0)
        #expect(IdleInhibitPreset.h4.durationSeconds == 14400.0)
        #expect(IdleInhibitPreset.indefinite.durationSeconds == nil)
    }

    @Test("Idle Inhibit Countdown Expiration and Bounds")
    func testIdleInhibitCountdown() {
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        let countdown = IdleInhibitCountdown(preset: .m30, startDate: baseDate)

        // Initial remaining seconds
        #expect(countdown.remainingSeconds(at: baseDate) == 1800.0)
        #expect(!countdown.isExpired(at: baseDate))
        #expect(countdown.progress(at: baseDate) == 0.0)

        // Advance 10 minutes (600 seconds)
        let midDate = baseDate.addingTimeInterval(600)
        #expect(countdown.remainingSeconds(at: midDate) == 1200.0)
        #expect(!countdown.isExpired(at: midDate))
        #expect(abs(countdown.progress(at: midDate) - (1.0 / 3.0)) < 0.001)

        // Advance past expiration (1805 seconds)
        let expiredDate = baseDate.addingTimeInterval(1805)
        #expect(countdown.remainingSeconds(at: expiredDate) == 0.0)
        #expect(countdown.isExpired(at: expiredDate))
        #expect(countdown.progress(at: expiredDate) == 1.0)

        // Indefinite countdown should not expire
        let indefinite = IdleInhibitCountdown(preset: .indefinite, startDate: baseDate)
        #expect(indefinite.remainingSeconds(at: baseDate) == nil)
        #expect(!indefinite.isExpired(at: expiredDate))
        #expect(indefinite.progress(at: expiredDate) == 0.0)
    }

    @Test("Idle Inhibit Formatted Remaining Time")
    func testIdleInhibitFormattedRemainingTime() {
        #expect(IdleInhibitCountdown.formatRemaining(seconds: 45) == "45s")
        #expect(IdleInhibitCountdown.formatRemaining(seconds: 125) == "2m 05s")
        #expect(IdleInhibitCountdown.formatRemaining(seconds: 3665) == "1h 01m")
        #expect(IdleInhibitCountdown.formatRemaining(seconds: 7320) == "2h 02m")

        #expect(IdleInhibitCountdown.formatRemainingShort(seconds: 45) == "45s")
        #expect(IdleInhibitCountdown.formatRemainingShort(seconds: 125) == "2m")
        #expect(IdleInhibitCountdown.formatRemainingShort(seconds: 3665) == "1h 1m")
    }

    // MARK: - 4. Codable Roundtrip Tests

    @Test("Idle Inhibit Models Codable Roundtrip")
    func testIdleInhibitCodable() throws {
        let original = IdleInhibitCountdown(
            preset: .h1,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            totalSeconds: 3600
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IdleInhibitCountdown.self, from: data)
        #expect(decoded == original)
    }

    @Test("SystemTelemetry Full Codable Roundtrip with Thermals and Throughput")
    func testSystemTelemetryFullCodable() throws {
        let telemetry = SystemTelemetry(
            cpuPercent: 24.5,
            ramPercent: 55.0,
            ramUsedGB: 8.8,
            ramTotalGB: 16.0,
            batteryPercent: 92,
            isCharging: false,
            timeRemainingMinutes: 300,
            gpuPercent: 12.0,
            networkUpBytesPerSec: 1048576.0, // 1.0 MB/s
            networkDownBytesPerSec: 5242880.0, // 5.0 MB/s
            cpuTemperature: 48.5,
            gpuTemperature: 44.0
        )

        let data = try JSONEncoder().encode(telemetry)
        let decoded = try JSONDecoder().decode(SystemTelemetry.self, from: data)
        #expect(decoded == telemetry)
        #expect(decoded.networkUpBytesPerSec == 1048576.0)
        #expect(decoded.networkDownBytesPerSec == 5242880.0)
        #expect(decoded.cpuTemperature == 48.5)
        #expect(decoded.gpuTemperature == 44.0)
    }

    @Test("SystemTelemetry Backwards Compatible Decoding of Legacy JSON")
    func testLegacySystemTelemetryDecoding() throws {
        // Legacy JSON without network and thermal fields
        let legacyJSON = """
        {
            "cpuPercent": 15.0,
            "ramPercent": 40.0,
            "ramUsedGB": 6.4,
            "ramTotalGB": 16.0,
            "isCharging": false
        }
        """
        let data = legacyJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SystemTelemetry.self, from: data)
        #expect(decoded.cpuPercent == 15.0)
        #expect(decoded.networkUpBytesPerSec == 0.0)
        #expect(decoded.networkDownBytesPerSec == 0.0)
        #expect(decoded.cpuTemperature == nil)
        #expect(decoded.gpuTemperature == nil)
    }
}
