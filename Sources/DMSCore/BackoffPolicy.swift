import Foundation

/// Pure, value-type capped backoff schedule shared by the IPC accept loop and the
/// MediaRemote bridge process supervisor.
///
/// `nextDelay()` walks `schedule` forward and clamps at the last entry, so a
/// persistently failing subsystem can never retry faster than `schedule.last`.
/// `reset()` returns to the first step after a success; `resetIfHealthy(uptime:)`
/// only resets when the subsystem stayed up for at least `healthyResetSeconds`,
/// so a crash-loop that dies instantly keeps growing toward the cap while a
/// subsystem that ran healthy for a while starts over from the bottom.
public struct CappedBackoffPolicy: Sendable, Equatable {
    /// Delay steps in seconds, ascending. Must not be empty.
    public let schedule: [TimeInterval]
    /// Current position in `schedule`, always clamped to `schedule.indices`.
    public var stepIndex: Int
    /// Uptime threshold above which `resetIfHealthy(uptime:)` resets the schedule.
    /// Defaults to `.infinity` (never auto-reset) unless a preset opts in.
    public let healthyResetSeconds: TimeInterval

    public init(schedule: [TimeInterval], stepIndex: Int = 0, healthyResetSeconds: TimeInterval = .infinity) {
        precondition(!schedule.isEmpty, "CappedBackoffPolicy requires a non-empty schedule")
        self.schedule = schedule
        self.stepIndex = min(max(stepIndex, 0), schedule.count - 1)
        self.healthyResetSeconds = healthyResetSeconds
    }

    /// Returns the delay for the current step, then advances the index (clamped at the last entry).
    public mutating func nextDelay() -> TimeInterval {
        let index = min(max(stepIndex, 0), schedule.count - 1)
        stepIndex = min(index + 1, schedule.count - 1)
        return schedule[index]
    }

    /// Returns to the first step. Call after a success.
    public mutating func reset() {
        stepIndex = 0
    }

    /// Resets only when `uptime` reached `healthyResetSeconds` — a subsystem that
    /// stayed healthy long enough is considered stable again; a crash-loop is not.
    public mutating func resetIfHealthy(uptime: TimeInterval) {
        if uptime >= healthyResetSeconds {
            stepIndex = 0
        }
    }

    /// Fast backoff for the IPC `accept()` loop: 10ms -> 250ms cap.
    public static let ipcAccept = CappedBackoffPolicy(schedule: [0.01, 0.025, 0.05, 0.1, 0.25])

    /// Backoff for MediaRemote bridge spawn/restart: 1s -> 30s cap, healthy after 30s uptime.
    public static let mediaBridge = CappedBackoffPolicy(
        schedule: [1.0, 2.0, 4.0, 8.0, 15.0, 30.0],
        healthyResetSeconds: 30.0
    )
}
