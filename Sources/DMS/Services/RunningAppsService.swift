import AppKit
import ApplicationServices
import Observation
import DMSCore

/// Manages running applications, currently active focused app, unhiding/hiding, and pinned dock applications.
@MainActor
@Observable
public final class RunningAppsService {
    public static let shared = RunningAppsService()

    public private(set) var activeApp: AppItem?
    public private(set) var runningApps: [AppItem] = []
    public private(set) var dockApps: [AppItem] = []

    public var hiddenApps: [AppItem] {
        runningApps.filter(\.isHidden)
    }

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
                isRunning: true,
                isHidden: front.isHidden
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
                isHidden: app.isHidden,
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
                    isHidden: false,
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

    public func isRunning(bundleID: String) -> Bool {
        runningApps.contains { $0.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame }
    }

    public func isHidden(bundleID: String) -> Bool {
        if let found = runningApps.first(where: { $0.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame }) {
            return found.isHidden
        }
        let live = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        return live.first?.isHidden ?? false
    }

    public func findRunning(bundleID: String, path: String? = nil) -> [NSRunningApplication] {
        var apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if apps.isEmpty {
            apps = NSWorkspace.shared.runningApplications.filter {
                $0.bundleIdentifier?.caseInsensitiveCompare(bundleID) == .orderedSame
            }
        }
        if apps.isEmpty, let path, !path.isEmpty {
            apps = NSWorkspace.shared.runningApplications.filter {
                $0.bundleURL?.path == path
            }
        }
        return apps
    }

    public func activate(bundleID: String, fallbackPath: String? = nil) {
        let apps = findRunning(bundleID: bundleID, path: fallbackPath)

        if apps.isEmpty {
            let launchURL: URL? = {
                if let path = fallbackPath, !path.isEmpty {
                    return URL(fileURLWithPath: path)
                }
                return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            }()
            if let launchURL {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: launchURL, configuration: config, completionHandler: nil)
            }
            return
        }

        // App is already running: unhide (if hidden) and activate to foreground.
        unhide(bundleID: bundleID, fallbackPath: fallbackPath, inBackground: false)
    }

    public func activate(app: AppItem) {
        activate(bundleID: app.bundleID, fallbackPath: app.path)
    }

    public func unhide(bundleID: String, fallbackPath: String? = nil, inBackground: Bool = false) {
        let apps = findRunning(bundleID: bundleID, path: fallbackPath)
        for app in apps {
            let pid = app.processIdentifier
            let axApp = AXUIElementCreateApplication(pid)
            AXUIElementSetAttributeValue(axApp, kAXHiddenAttribute as CFString, kCFBooleanFalse)
            _ = app.unhide()
            runAppleScript("tell application \"System Events\" to set visible of (first process whose unix id is \(pid)) to true")
        }
        if !inBackground {
            for app in apps {
                app.activate()
                if let bundleURL = app.bundleURL {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    NSWorkspace.shared.openApplication(at: bundleURL, configuration: config, completionHandler: nil)
                }
                let pid = app.processIdentifier
                runAppleScript("tell application \"System Events\" to set frontmost of (first process whose unix id is \(pid)) to true")
            }
        }
        refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.refresh()
        }
    }

    public func unhide(app: AppItem, inBackground: Bool = false) {
        unhide(bundleID: app.bundleID, fallbackPath: app.path, inBackground: inBackground)
    }

    public func hide(bundleID: String, fallbackPath: String? = nil) {
        let apps = findRunning(bundleID: bundleID, path: fallbackPath)
        for app in apps {
            let pid = app.processIdentifier
            let axApp = AXUIElementCreateApplication(pid)
            AXUIElementSetAttributeValue(axApp, kAXHiddenAttribute as CFString, kCFBooleanTrue)
            _ = app.hide()
            runAppleScript("tell application \"System Events\" to set visible of (first process whose unix id is \(pid)) to false")
        }
        refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.refresh()
        }
    }

    public func hide(app: AppItem) {
        hide(bundleID: app.bundleID, fallbackPath: app.path)
    }

    public func unhideAll(inBackground: Bool = true) {
        for item in runningApps where item.isHidden {
            unhide(bundleID: item.bundleID, fallbackPath: item.path, inBackground: inBackground)
        }
        runAppleScript("tell application \"System Events\" to set visible of every process whose visible is false to true")
        refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.refresh()
        }
    }

    public func quit(bundleID: String, fallbackPath: String? = nil) {
        let apps = findRunning(bundleID: bundleID, path: fallbackPath)
        for app in apps {
            app.terminate()
        }
        refresh()
    }

    public func quit(app: AppItem) {
        quit(bundleID: app.bundleID, fallbackPath: app.path)
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

    public func togglePinned(bundleID: String) {
        togglePin(bundleID: bundleID)
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> Bool {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(&error)
        if let error {
            NSLog("[RunningAppsService] AppleScript error: %@", error)
            return false
        }
        return true
    }
}
