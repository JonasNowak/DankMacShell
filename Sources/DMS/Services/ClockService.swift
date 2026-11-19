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
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupSystemObservers()
        observeConfig()
        scheduleNextTick()
    }

    /// True when any enabled `clock` bar widget has `showSeconds` turned on.
    private func secondsTickNeeded() -> Bool {
        ConfigStore.shared.config.barConfigs.contains { bar in
            let entries = bar.layout.left + bar.layout.center + bar.layout.right
            return entries.contains {
                $0.enabled && $0.widgetId == "clock" && ($0.options["showSeconds"]?.boolValue ?? false)
            }
        }
    }

    /// Re-syncs the tick cadence when the set of enabled clock widgets changes.
    private func observeConfig() {
        ConfigStore.shared.$config
            .map { config in
                config.barConfigs.contains { bar in
                    let entries = bar.layout.left + bar.layout.center + bar.layout.right
                    return entries.contains {
                        $0.enabled && $0.widgetId == "clock" && ($0.options["showSeconds"]?.boolValue ?? false)
                    }
                }
            }
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.resync()
                }
            }
            .store(in: &cancellables)
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

        let fireDelay: TimeInterval
        if secondsTickNeeded() {
            // A bar clock widget shows seconds: tick every second, aligned to the
            // whole-second boundary.
            fireDelay = ClockSyncMath.delayToNextSecond(from: now)
        } else {
            // No seconds display: tick once per minute, aligned to the minute
            // boundary, instead of waking the process every second.
            let ts = now.timeIntervalSinceReferenceDate
            fireDelay = max(0.001, 60.0 - ts.truncatingRemainder(dividingBy: 60.0) + 0.005)
        }

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
