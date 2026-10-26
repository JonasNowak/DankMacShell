import Foundation

/// Temperature scale units supported across DMS widgets and settings.
public enum TemperatureUnit: String, Sendable, Codable, CaseIterable {
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"

    public func convert(celsius: Double) -> Double {
        switch self {
        case .celsius:
            return celsius
        case .fahrenheit:
            return (celsius * 9.0 / 5.0) + 32.0
        }
    }

    public var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}

/// M3 expressive thermal severity thresholds.
public enum ThermalSeverity: String, Sendable, Codable, Equatable {
    case normal
    case warning
    case critical
}

/// Hardware telemetry metrics for CPU, RAM, GPU, Battery, Network throughput, and Thermals.
public struct SystemTelemetry: Sendable, Codable, Equatable {
    public var cpuPercent: Double
    public var ramPercent: Double
    public var ramUsedGB: Double
    public var ramTotalGB: Double
    public var batteryPercent: Int?
    public var isCharging: Bool
    public var timeRemainingMinutes: Int?
    public var gpuPercent: Double?
    public var networkUpBytesPerSec: Double
    public var networkDownBytesPerSec: Double
    public var cpuTemperature: Double?
    public var gpuTemperature: Double?

    public init(
        cpuPercent: Double = 0.0,
        ramPercent: Double = 0.0,
        ramUsedGB: Double = 0.0,
        ramTotalGB: Double = 0.0,
        batteryPercent: Int? = nil,
        isCharging: Bool = false,
        timeRemainingMinutes: Int? = nil,
        gpuPercent: Double? = nil,
        networkUpBytesPerSec: Double = 0.0,
        networkDownBytesPerSec: Double = 0.0,
        cpuTemperature: Double? = nil,
        gpuTemperature: Double? = nil
    ) {
        self.cpuPercent = cpuPercent
        self.ramPercent = ramPercent
        self.ramUsedGB = ramUsedGB
        self.ramTotalGB = ramTotalGB
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.timeRemainingMinutes = timeRemainingMinutes
        self.gpuPercent = gpuPercent
        self.networkUpBytesPerSec = networkUpBytesPerSec
        self.networkDownBytesPerSec = networkDownBytesPerSec
        self.cpuTemperature = cpuTemperature
        self.gpuTemperature = gpuTemperature
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.cpuPercent = try container.decodeIfPresent(Double.self, forKey: .cpuPercent) ?? 0.0
        self.ramPercent = try container.decodeIfPresent(Double.self, forKey: .ramPercent) ?? 0.0
        self.ramUsedGB = try container.decodeIfPresent(Double.self, forKey: .ramUsedGB) ?? 0.0
        self.ramTotalGB = try container.decodeIfPresent(Double.self, forKey: .ramTotalGB) ?? 0.0
        self.batteryPercent = try container.decodeIfPresent(Int.self, forKey: .batteryPercent)
        self.isCharging = try container.decodeIfPresent(Bool.self, forKey: .isCharging) ?? false
        self.timeRemainingMinutes = try container.decodeIfPresent(Int.self, forKey: .timeRemainingMinutes)
        self.gpuPercent = try container.decodeIfPresent(Double.self, forKey: .gpuPercent)
        self.networkUpBytesPerSec = try container.decodeIfPresent(Double.self, forKey: .networkUpBytesPerSec) ?? 0.0
        self.networkDownBytesPerSec = try container.decodeIfPresent(Double.self, forKey: .networkDownBytesPerSec) ?? 0.0
        self.cpuTemperature = try container.decodeIfPresent(Double.self, forKey: .cpuTemperature)
        self.gpuTemperature = try container.decodeIfPresent(Double.self, forKey: .gpuTemperature)
    }

    // MARK: - Throughput Formatting Helpers

    /// Formats throughput in standard human-readable format (`B/s`, `KB/s`, `MB/s`, `GB/s`).
    public static func formatByteRate(_ bytesPerSec: Double) -> String {
        let b = max(0.0, bytesPerSec)
        if b < 1024.0 {
            return String(format: "%.0f B/s", b)
        } else if b < 1024.0 * 1024.0 {
            let kb = b / 1024.0
            return kb >= 100.0 ? String(format: "%.0f KB/s", kb) : String(format: "%.1f KB/s", kb)
        } else if b < 1024.0 * 1024.0 * 1024.0 {
            let mb = b / (1024.0 * 1024.0)
            return mb >= 100.0 ? String(format: "%.0f MB/s", mb) : String(format: "%.1f MB/s", mb)
        } else {
            let gb = b / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.2f GB/s", gb)
        }
    }

    /// Formats throughput in compact format suitable for narrow bar widgets (`0B`, `1.5K`, `12M`).
    public static func formatCompactByteRate(_ bytesPerSec: Double) -> String {
        let b = max(0.0, bytesPerSec)
        if b < 1024.0 {
            return String(format: "%.0fB", b)
        } else if b < 1024.0 * 1024.0 {
            let kb = b / 1024.0
            return kb >= 10.0 ? String(format: "%.0fK", kb) : String(format: "%.1fK", kb)
        } else if b < 1024.0 * 1024.0 * 1024.0 {
            let mb = b / (1024.0 * 1024.0)
            return mb >= 10.0 ? String(format: "%.0fM", mb) : String(format: "%.1fM", mb)
        } else {
            let gb = b / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.1fG", gb)
        }
    }

    // MARK: - Thermal Threshold Helpers

    /// Computes M3 Expressive thermal severity for a temperature value in Celsius.
    /// Normal: < 70°C; Warning: 70°C–85°C; Critical: > 85°C.
    public static func thermalSeverity(forCelsius tempC: Double) -> ThermalSeverity {
        if tempC > 85.0 {
            return .critical
        } else if tempC >= 70.0 {
            return .warning
        } else {
            return .normal
        }
    }

    /// Formats a Celsius temperature into the user-specified unit with appropriate unit symbol.
    public static func formatTemperature(_ celsius: Double, unit: TemperatureUnit = .celsius) -> String {
        let converted = unit.convert(celsius: celsius)
        return "\(Int(round(converted)))\(unit.symbol)"
    }
}
