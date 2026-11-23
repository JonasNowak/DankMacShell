import Foundation
import Combine

/// Pomodoro focus/break timer backing the `pomodoro-timer` plugin bar widget.
/// The 1s countdown Timer only exists while a session is running, so the service
/// consumes 0% CPU when paused or idle.
@MainActor
public final class PomodoroService: ObservableObject {
    public static let shared = PomodoroService()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isBreak: Bool = false
    @Published public private(set) var remainingSeconds: Int = 25 * 60
    @Published public private(set) var endDate: Date? = nil
    @Published public private(set) var completedSessions: Int = 0
    @Published public private(set) var workMinutes: Int = 25
    @Published public private(set) var breakMinutes: Int = 5

    public var phaseLabel: String { isBreak ? "Break" : "Focus" }

    public var formattedRemaining: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    /// Total seconds of the current phase (focus or break) based on the configured durations.
    public var totalPhaseSeconds: Int {
        (isBreak ? breakMinutes : workMinutes) * 60
    }

    /// Elapsed fraction of the current phase, 0.0...1.0.
    public var progress: Double {
        let total = totalPhaseSeconds
        guard total > 0 else { return 0.0 }
        let elapsed = total - remainingSeconds
        return min(1.0, max(0.0, Double(elapsed) / Double(total)))
    }

    private var timer: Timer?

    private init() {}

    public func toggleStartPause() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        startTimer()
        WidgetSnapshotService.shared.syncNow(forceReload: true)
    }

    public func pause() {
        guard isRunning else { return }
        isRunning = false
        stopTimer()
        endDate = nil
        WidgetSnapshotService.shared.syncNow(forceReload: true)
    }

    public func reset() {
        isRunning = false
        stopTimer()
        isBreak = false
        remainingSeconds = workMinutes * 60
        endDate = nil
        WidgetSnapshotService.shared.syncNow(forceReload: true)
    }

    /// Applies a work/break preset: updates the durations and stops/resets cleanly
    /// to the new work duration, then pushes a fresh widget snapshot.
    public func applyPreset(workMinutes: Int, breakMinutes: Int) {
        let clampedWork = max(1, min(180, workMinutes))
        let clampedBreak = max(1, min(60, breakMinutes))
        self.workMinutes = clampedWork
        self.breakMinutes = clampedBreak
        isRunning = false
        stopTimer()
        isBreak = false
        remainingSeconds = clampedWork * 60
        endDate = nil
        WidgetSnapshotService.shared.syncNow(forceReload: true)
    }

    public func skipPhase() {
        advancePhase()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isRunning else { return }
        if let end = endDate {
            remainingSeconds = max(0, Int(end.timeIntervalSinceNow.rounded()))
        } else {
            remainingSeconds = max(0, remainingSeconds - 1)
        }
        if remainingSeconds <= 0 {
            advancePhase()
        }
    }

    /// Phase transition shared by the countdown hitting 0 and `skipPhase()`:
    /// counts a finished focus session, flips focus/break, sets the next phase
    /// duration, pauses, notifies, and pushes a fresh widget snapshot.
    private func advancePhase() {
        if !isBreak {
            completedSessions += 1
        }
        isBreak.toggle()
        if isBreak {
            // Long break every 4th session: 3x the configured break (15 min at the 5 min default).
            remainingSeconds = (completedSessions % 4 == 0) ? breakMinutes * 3 * 60 : breakMinutes * 60
        } else {
            remainingSeconds = workMinutes * 60
        }
        isRunning = false
        stopTimer()
        endDate = nil

        let message: String
        if isBreak {
            message = "Focus session complete — break started (\(formattedRemaining))"
        } else {
            message = "Break over — focus started (\(formattedRemaining))"
        }
        ToastCenter.shared.show(icon: "timer", message: message)
        SoundEffectService.shared.playNotification()
        WidgetSnapshotService.shared.syncNow(forceReload: true)
    }
}
