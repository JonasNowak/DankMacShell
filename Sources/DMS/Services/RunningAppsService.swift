import AppKit
import Observation
import DMSCore

/// Manages running applications, currently active focused app, and pinned dock applications.
@MainActor
@Observable
public final class RunningAppsService {
    public static let shared = RunningAppsService()

    public private(set) var activeApp: AppItem?
    public private(set) var runningApps: [AppItem] = []
    public private(set) var dockApps: [AppItem] = []

    private init() {
        refresh()
        setupObservers()
    }

    private func setupObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let notifications = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        ]

        for notif in notifications {
            center.addObserver(
                forName: notif,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            }
        }
    }

    public func refresh() {
        let workspace = NSWorkspace.shared
        let running = workspace.runningApplications.filter { $0.activationPolicy == .regular }
        let currentFront = workspace.frontmostApplication

        if let front = currentFront, let name = front.localizedName, let bid = front.bundleIdentifier {
            activeApp = AppItem(
                name: name,
                bundleID: bid,
                path: front.bundleURL?.path ?? "",
                isRunning: true
            )
        }

        var apps: [AppItem] = []
        for app in running {
            guard let name = app.localizedName, let bid = app.bundleIdentifier else { continue }
            let path = app.bundleURL?.path ?? ""
            let isPinned = ConfigStore.shared.config.pinnedApps.contains(bid)
            apps.append(AppItem(
                name: name,
                bundleID: bid,
                path: path,
                isRunning: true,
                isPinned: isPinned
            ))
        }
        self.runningApps = apps

        // Combine pinned apps with running apps
        let pinnedIDs = ConfigStore.shared.config.pinnedApps
        var dockList: [AppItem] = []

        // Add pinned apps first
        for pid in pinnedIDs {
            if let runningMatch = apps.first(where: { $0.bundleID == pid }) {
                dockList.append(runningMatch)
            } else if let url = workspace.urlForApplication(withBundleIdentifier: pid) {
                let name = FileManager.default.displayName(atPath: url.path)
                dockList.append(AppItem(
                    name: name,
                    bundleID: pid,
                    path: url.path,
                    isRunning: false,
                    isPinned: true
                ))
            }
        }

        // Add unpinned running apps
        for app in apps where !pinnedIDs.contains(app.bundleID) {
            dockList.append(app)
        }

        self.dockApps = dockList
    }

    public func activate(app: AppItem) {
        let running = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == app.bundleID }
        if let running {
            running.activate(options: [.activateIgnoringOtherApps])
        } else if let url = URL(string: "file://" + app.path) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    public func quit(app: AppItem) {
        let running = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == app.bundleID }
        running?.terminate()
    }

    public func hide(app: AppItem) {
        let running = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == app.bundleID }
        running?.hide()
    }

    public func togglePin(bundleID: String) {
        ConfigStore.shared.update { cfg in
            if let idx = cfg.pinnedApps.firstIndex(of: bundleID) {
                cfg.pinnedApps.remove(at: idx)
            } else {
                cfg.pinnedApps.append(bundleID)
            }
        }
        refresh()
    }
}
