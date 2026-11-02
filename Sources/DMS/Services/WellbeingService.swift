import Foundation
import AppKit
import Combine
import DMSCore

/// Service tracking frontmost application active focus time, daily usage records, and quota limits.
@MainActor
public final class WellbeingService: ObservableObject {
    public static let shared = WellbeingService()

    @Published public private(set) var store: WellbeingStoreData
    @Published public private(set) var todayTotalSeconds: TimeInterval = 0
    @Published public private(set) var currentFrontmostApp: String = ""

    private let storageURL: URL
    private var activeFocusSession: (bundleID: String, appName: String, startTime: Date)?
    private var flushTimer: Timer?
    private var alertedLimits: Set<String> = []

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dmsDir = appSupport.appendingPathComponent("DMS", isDirectory: true)
        try? FileManager.default.createDirectory(at: dmsDir, withIntermediateDirectories: true)
        self.storageURL = dmsDir.appendingPathComponent("wellbeing.json")
        self.store = WellbeingStoreData()

        loadStore()
        setupObservers()
        startPeriodicFlush()

        // Capture initial frontmost app
        if let front = NSWorkspace.shared.frontmostApplication,
           let bid = front.bundleIdentifier,
           let name = front.localizedName {
            currentFrontmostApp = name
            activeFocusSession = (bundleID: bid, appName: name, startTime: Date())
        }
        updateTodayTotal()
    }

    private func setupObservers() {
        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard let app = NSWorkspace.shared.frontmostApplication,
                      let bid = app.bundleIdentifier,
                      let name = app.localizedName else { return }

                self.appDidActivate(bundleID: bid, appName: name)
            }
        }

        center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pauseTracking()
            }
        }

        center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pauseTracking()
            }
        }

        center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeTracking()
            }
        }

        center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeTracking()
            }
        }
    }

    private func startPeriodicFlush() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.flushInFlight()
            }
        }
    }

    private func appDidActivate(bundleID: String, appName: String) {
        flushInFlight()
        currentFrontmostApp = appName
        activeFocusSession = (bundleID: bundleID, appName: appName, startTime: Date())
    }

    private func pauseTracking() {
        flushInFlight()
        activeFocusSession = nil
    }

    private func resumeTracking() {
        if let front = NSWorkspace.shared.frontmostApplication,
           let bid = front.bundleIdentifier,
           let name = front.localizedName {
            currentFrontmostApp = name
            activeFocusSession = (bundleID: bid, appName: name, startTime: Date())
        }
    }

    public func flushInFlight() {
        guard let session = activeFocusSession else { return }
        let now = Date()
        let elapsed = now.timeIntervalSince(session.startTime)
        guard elapsed >= 0.5 else { return }

        let dateKey = WellbeingFormatter.dateKey(for: now)
        store.addUsage(
            bundleID: session.bundleID,
            appName: session.appName,
            dateKey: dateKey,
            seconds: elapsed
        )

        activeFocusSession = (bundleID: session.bundleID, appName: session.appName, startTime: now)
        updateTodayTotal()
        checkLimit(bundleID: session.bundleID, appName: session.appName, dateKey: dateKey)
        saveStoreDebounced()
    }

    private func updateTodayTotal() {
        let todayKey = WellbeingFormatter.dateKey(for: Date())
        todayTotalSeconds = store.totalDuration(for: todayKey)
    }

    private func checkLimit(bundleID: String, appName: String, dateKey: String) {
        let alertKey = "\(dateKey)_\(bundleID)"
        guard !alertedLimits.contains(alertKey) else { return }

        if store.isLimitExceeded(bundleID: bundleID, dateKey: dateKey) {
            alertedLimits.insert(alertKey)
            if let limit = store.limits[bundleID] {
                ToastCenter.shared.show(
                    icon: "hourglass.bottomhalf.filled",
                    message: "Daily limit of \(limit.dailyLimitMinutes)m reached for \(appName)"
                )
            }
        }
    }

    public func setDailyLimit(bundleID: String, appName: String, minutes: Int, enabled: Bool = true) {
        store.setLimit(bundleID: bundleID, appName: appName, minutes: minutes, enabled: enabled)
        saveStoreImmediate()
    }

    public func removeDailyLimit(bundleID: String) {
        store.removeLimit(bundleID: bundleID)
        saveStoreImmediate()
    }

    private func loadStore() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              var decoded = try? JSONDecoder().decode(WellbeingStoreData.self, from: data) else {
            return
        }

        decoded.prune(currentDate: Date(), retentionDays: 92)
        self.store = decoded
    }

    private var saveTask: Task<Void, Never>?

    private func saveStoreDebounced() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            if !Task.isCancelled {
                self.saveStoreImmediate()
            }
        }
    }

    private func saveStoreImmediate() {
        var snapshot = store
        snapshot.prune(currentDate: Date(), retentionDays: snapshot.retentionDays)
        let target = storageURL

        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: target, options: .atomic)
        }
    }

    isolated deinit {
        flushTimer?.invalidate()
    }
}
