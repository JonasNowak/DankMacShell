import Foundation
import AppKit
import Combine
import Darwin
import DMSCore

/// Service tracking frontmost application active focus time, daily usage records, and quota limits.
@MainActor
public final class WellbeingService: ObservableObject {
    public static let shared = WellbeingService()

    @Published public private(set) var store: WellbeingStoreData
    @Published public private(set) var todayTotalSeconds: TimeInterval = 0
    @Published public private(set) var currentFrontmostApp: String = ""
    @Published public private(set) var isMacOSScreenTimeActive: Bool = true
    @Published public private(set) var isTrackingActive: Bool = true

    private let storageURL: URL
    private var activeFocusSession: (bundleID: String, appName: String, startTime: Date)?
    private var flushTimer: Timer?
    private var statusCheckTimer: Timer?
    private var alertedLimits: Set<String> = []
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dmsDir = appSupport.appendingPathComponent("DMS", isDirectory: true)
        try? FileManager.default.createDirectory(at: dmsDir, withIntermediateDirectories: true)
        self.storageURL = dmsDir.appendingPathComponent("wellbeing.json")
        self.store = WellbeingStoreData()

        loadStore()
        updateMacOSScreenTimeStatus()
        recomputeTrackingState()
        setupObservers()
        startPeriodicFlush()
        startPeriodicStatusCheck()

        // Capture initial frontmost app
        if isTrackingActive,
           let front = NSWorkspace.shared.frontmostApplication,
           let bid = front.bundleIdentifier,
           let name = front.localizedName {
            currentFrontmostApp = name
            activeFocusSession = (bundleID: bid, appName: name, startTime: Date())
        } else if let front = NSWorkspace.shared.frontmostApplication, let name = front.localizedName {
            currentFrontmostApp = name
        }
        updateTodayTotal()
    }

    public func updateMacOSScreenTimeStatus() {
        var pids = [pid_t](repeating: 0, count: 4096)
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.size * pids.count))
        guard bytes > 0 else {
            self.isMacOSScreenTimeActive = true
            return
        }

        let count = min(Int(bytes) / MemoryLayout<pid_t>.size, pids.count)
        var found = false
        for i in 0..<count {
            let pid = pids[i]
            if pid <= 0 { continue }
            var nameBuffer = [CChar](repeating: 0, count: 256)
            let len = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            if len > 0 {
                let name = nameBuffer.withUnsafeBufferPointer { ptr in
                    ptr.baseAddress != nil ? String(cString: ptr.baseAddress!) : ""
                }
                if name == "ScreenTimeAgent" {
                    found = true
                    break
                }
            }
        }

        if self.isMacOSScreenTimeActive != found {
            self.isMacOSScreenTimeActive = found
        }
    }

    public func recomputeTrackingState() {
        let cfg = ConfigStore.shared.config
        let shouldTrack = cfg.enableWellbeing && (!cfg.syncWellbeingWithMacOS || isMacOSScreenTimeActive)
        if self.isTrackingActive != shouldTrack {
            self.isTrackingActive = shouldTrack
            if !shouldTrack {
                pauseTracking()
            } else if activeFocusSession == nil {
                resumeTracking()
            }
        }
    }

    public func openMacOSScreenTimeSettings() {
        let modernURL = URL(string: "x-apple.systempreferences:com.apple.Screen-Time-Settings.extension")
        let legacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.screentime")
        if let modernURL, NSWorkspace.shared.open(modernURL) {
            return
        } else if let legacyURL {
            NSWorkspace.shared.open(legacyURL)
        }
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

        ConfigStore.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMacOSScreenTimeStatus()
                self?.recomputeTrackingState()
            }
            .store(in: &cancellables)
    }

    private func startPeriodicFlush() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isTrackingActive else { return }
                self.flushInFlight()
            }
        }
    }

    private func startPeriodicStatusCheck() {
        statusCheckTimer?.invalidate()
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMacOSScreenTimeStatus()
                self?.recomputeTrackingState()
            }
        }
    }

    private func appDidActivate(bundleID: String, appName: String) {
        guard isTrackingActive else {
            currentFrontmostApp = appName
            activeFocusSession = nil
            return
        }
        flushInFlight()
        currentFrontmostApp = appName
        activeFocusSession = (bundleID: bundleID, appName: appName, startTime: Date())
    }

    private func pauseTracking() {
        flushInFlight()
        activeFocusSession = nil
    }

    private func resumeTracking() {
        guard isTrackingActive else { return }
        if let front = NSWorkspace.shared.frontmostApplication,
           let bid = front.bundleIdentifier,
           let name = front.localizedName {
            currentFrontmostApp = name
            activeFocusSession = (bundleID: bid, appName: name, startTime: Date())
        }
    }

    public func flushInFlight() {
        guard isTrackingActive else {
            activeFocusSession = nil
            return
        }
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
        statusCheckTimer?.invalidate()
    }
}
