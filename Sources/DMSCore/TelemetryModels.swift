import Foundation

/// Hardware telemetry metrics for CPU, RAM, GPU, and Battery.
public struct SystemTelemetry: Sendable, Codable, Equatable {
    public var cpuPercent: Double
    public var ramPercent: Double
    public var ramUsedGB: Double
    public var ramTotalGB: Double
    public var batteryPercent: Int?
    public var isCharging: Bool
    public var timeRemainingMinutes: Int?
    public var gpuPercent: Double?

    public init(
        cpuPercent: Double = 0.0,
        ramPercent: Double = 0.0,
        ramUsedGB: Double = 0.0,
        ramTotalGB: Double = 0.0,
        batteryPercent: Int? = nil,
        isCharging: Bool = false,
        timeRemainingMinutes: Int? = nil,
        gpuPercent: Double? = nil
    ) {
        self.cpuPercent = cpuPercent
        self.ramPercent = ramPercent
        self.ramUsedGB = ramUsedGB
        self.ramTotalGB = ramTotalGB
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.timeRemainingMinutes = timeRemainingMinutes
        self.gpuPercent = gpuPercent
    }
}
