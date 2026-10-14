import Foundation

/// Represents a running system process for the DMS Process Manager modal.
public struct ProcessInfoItem: Sendable, Codable, Identifiable, Equatable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double
    public let memoryMB: Double
    public let user: String

    public init(pid: Int32, name: String, cpuPercent: Double, memoryMB: Double, user: String) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.user = user
    }
}
