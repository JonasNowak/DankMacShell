import Foundation
import AppKit
import Combine
import DMSCore

/// Centralized, high-precision wall-clock synchronization service.
/// Eliminates timer drift, struct-recreation timer resets, and phase offsets against macOS system time.
@MainActor
public final class ClockService: ObservableObject {
    public static let shared = ClockService()

    @Published public private(set) var currentDate: Date = Date()

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    private init() {
        setupSystemObservers()
        scheduleNextTick()
    }

    private func setupSystemObservers() {
        let center = NotificationCenter.default
        let wsCenter = NSWorkspace.shared.notificationCenter

        // Re-sync immediately on system wake
        observers.append(
            wsCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.resync()
                }
            }
        )

        // Re-sync on system clock adjustments (NTP, manual time set)
        observers.append(
            center.addObserver(
                forName: Notification.Name.NSSystemClockDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.resync()
                }
            }
        )

        // Re-sync on timezone changes
        observers.append(
            center.addObserver(
                forName: Notification.Name.NSSystemTimeZoneDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    NSTimeZone.resetSystemTimeZone()
                    self?.resync()
                }
            }
        )

        // Re-sync on day change (midnight transition)
        observers.append(
            center.addObserver(
                forName: Notification.Name.NSCalendarDayChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.resync()
                }
            }
        )
    }

    public func resync() {
        scheduleNextTick()
    }

    private func scheduleNextTick() {
        timer?.invalidate()
        timer = nil

        let now = Date()
        self.currentDate = now

        let fireDelay = ClockSyncMath.delayToNextSecond(from: now)

        let t = Timer(timeInterval: fireDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleNextTick()
            }
        }
        t.tolerance = 0.01 // Tight tolerance: 10ms
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    deinit {
        timer?.invalidate()
        for obs in observers {
            NotificationCenter.default.removeObserver(obs)
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }
}
