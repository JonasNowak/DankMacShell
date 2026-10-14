import AppKit
import Combine
import DMSCore

/// Represents an application with an active window in the current workspace.
public struct WorkspaceAppItem: Identifiable, Equatable {
    public var id: pid_t { pid }
    public let pid: pid_t
    public let name: String
    public let bundleID: String
    public let path: String
    public let isActive: Bool

    public init(pid: pid_t, name: String, bundleID: String, path: String, isActive: Bool = false) {
        self.pid = pid
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.isActive = isActive
    }
}

/// Service that monitors the active macOS workspace (Space) and the applications open on that workspace.
@MainActor
public final class WorkspaceService: ObservableObject {
    public static let shared = WorkspaceService()

    @Published public private(set) var activeSpaceIndex: Int = 1
    @Published public private(set) var spacesCount: Int = 4
    @Published public private(set) var currentWorkspaceApps: [WorkspaceAppItem] = []

    private var cancellables = Set<AnyCancellable>()
    private var skyLightHandle: UnsafeMutableRawPointer?
    private var cgsMainConnectionID: (@convention(c) () -> Int32)?
    private var cgsCopyManagedDisplaySpaces: (@convention(c) (Int32) -> CFArray?)?

    private init() {
        setupSkyLight()
        updateSpaces()
        updateWorkspaceApps()
        registerObservers()
    }

    private func setupSkyLight() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) {
            skyLightHandle = handle
            if let connSym = dlsym(handle, "CGSMainConnectionID") {
                cgsMainConnectionID = unsafeBitCast(connSym, to: (@convention(c) () -> Int32).self)
            }
            if let spacesSym = dlsym(handle, "CGSCopyManagedDisplaySpaces") {
                cgsCopyManagedDisplaySpaces = unsafeBitCast(spacesSym, to: (@convention(c) (Int32) -> CFArray?).self)
            }
        }
    }

    private func registerObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter

        // Listen for active workspace changes
        wsCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSpaces()
                self?.updateWorkspaceApps()
            }
            .store(in: &cancellables)

        // Listen for active app changes
        wsCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateWorkspaceApps()
            }
            .store(in: &cancellables)

        // Listen for launches and terminations
        wsCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateWorkspaceApps()
            }
            .store(in: &cancellables)

        wsCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateWorkspaceApps()
            }
            .store(in: &cancellables)
    }

    /// Queries the current space index and count via SkyLight CGS API.
    public func updateSpaces() {
        guard let getConn = cgsMainConnectionID,
              let getSpaces = cgsCopyManagedDisplaySpaces else {
            return
        }

        let conn = getConn()
        guard let displays = getSpaces(conn) as? [[String: Any]] else {
            return
        }

        for display in displays {
            guard let spaces = display["Spaces"] as? [[String: Any]],
                  let currentSpace = display["Current Space"] as? [String: Any] else {
                continue
            }

            let currentID = currentSpace["ManagedSpaceID"] as? Int ?? currentSpace["id64"] as? Int
            // Filter to normal user spaces (type 0)
            let userSpaces = spaces.filter { ($0["type"] as? Int ?? 0) == 0 }
            let count = max(userSpaces.count, 1)

            var activeIdx = 1
            for (idx, space) in userSpaces.enumerated() {
                let sid = space["ManagedSpaceID"] as? Int ?? space["id64"] as? Int
                if sid == currentID {
                    activeIdx = idx + 1
                    break
                }
            }

            self.spacesCount = max(count, max(activeIdx, 4))
            self.activeSpaceIndex = activeIdx
            break
        }
    }

    /// Inspects windows on the current screen/space and updates `currentWorkspaceApps`.
    public func updateWorkspaceApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        let runningDict = Dictionary(uniqueKeysWithValues: runningApps.map { ($0.processIdentifier, $0) })
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let dmsPID = ProcessInfo.processInfo.processIdentifier

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        var seenPIDs = Set<pid_t>()
        var apps: [WorkspaceAppItem] = []

        for info in infoList {
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            let pid = info[kCGWindowOwnerPID as String] as? Int32 ?? 0
            let bounds = info[kCGWindowBounds as String] as? [String: Any]
            let width = bounds?["Width"] as? CGFloat ?? 0
            let height = bounds?["Height"] as? CGFloat ?? 0
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1.0

            // Normal window layer, reasonable size, visible, not DMS itself
            if layer == 0 && width > 60 && height > 60 && alpha > 0.05 && pid != dmsPID && !seenPIDs.contains(pid) {
                seenPIDs.insert(pid)
                if let app = runningDict[pid], app.activationPolicy == .regular {
                    let name = app.localizedName ?? (info[kCGWindowOwnerName as String] as? String ?? "App")
                    let bundleID = app.bundleIdentifier ?? ""
                    let path = app.bundleURL?.path ?? ""
                    let isActive = (pid == frontPID)

                    apps.append(WorkspaceAppItem(
                        pid: pid,
                        name: name,
                        bundleID: bundleID,
                        path: path,
                        isActive: isActive
                    ))
                }
            }
        }

        self.currentWorkspaceApps = apps
    }

    /// Switches to the specified workspace number.
    public func switchSpace(_ number: Int) {
        self.activeSpaceIndex = number

        let src = CGEventSource(stateID: .hidSystemState)
        let keyCodes: [Int: CGKeyCode] = [
            1: 18, 2: 19, 3: 20, 4: 21,
            5: 23, 6: 22, 7: 26, 8: 28, 9: 25
        ]

        if let code = keyCodes[number] {
            let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
            down?.flags = .maskControl
            down?.post(tap: .cghidEventTap)

            let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)
            up?.flags = .maskControl
            up?.post(tap: .cghidEventTap)
        }

        // Refresh shortly after switching
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateSpaces()
            self?.updateWorkspaceApps()
        }
    }

    /// Activates the given workspace application.
    public func activate(app: WorkspaceAppItem) {
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == app.pid }) {
            running.activate()
        }
        updateWorkspaceApps()
    }
}
