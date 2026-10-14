import AppKit
import Combine
import DMSCore

// MARK: - OmniWM IPC Decodable Models

struct OmniWMAnyMessage: Decodable {
    let channel: String?
    let kind: String?
    let ok: Bool?
    let result: OmniWMAnyResult?
}

struct OmniWMAnyResult: Decodable {
    let kind: String?
    let payload: OmniWMAnyPayload?
}

struct OmniWMAnyPayload: Decodable {
    let workspace: OmniWMWorkspace?
    let workspaces: [OmniWMWorkspaceDetail]?
    let windows: [OmniWMWindowItem]?
    let monitors: [OmniWMMonitor]?
    let focusedApp: OmniWMAppInfo?
}

struct OmniWMWorkspaceDetail: Decodable {
    let id: String
    let number: Int
    let displayName: String
    let rawName: String?
    let isCurrent: Bool?
    let isFocused: Bool?
}

struct OmniWMWindowItem: Decodable {
    let id: String
    let pid: pid_t?
    let title: String?
    let isFocused: Bool?
    let isVisible: Bool?
    let mode: String?
    let app: OmniWMAppInfo?
    let workspace: OmniWMWorkspace?
}

struct OmniWMMonitor: Decodable {
    let id: String
    let name: String?
    let workspaces: [OmniWMMonitorWorkspace]?
}

struct OmniWMMonitorWorkspace: Decodable {
    let id: String
    let number: Int
    let displayName: String
    let rawName: String?
    let isFocused: Bool?
    let windows: [OmniWMMonitorWindowSummary]?
}

struct OmniWMMonitorWindowSummary: Decodable {
    let id: String
    let appName: String
    let bundleId: String?
    let isFocused: Bool?
    let windowCount: Int?
}

struct OmniWMWorkspace: Decodable {
    let id: String
    let number: Int
    let displayName: String
    let rawName: String?
}

struct OmniWMAppInfo: Decodable {
    let name: String?
    let bundleId: String?
}

// MARK: - WorkspaceService

/// Service that monitors active workspaces and open applications across macOS native spaces and OmniWM virtual workspaces.
@MainActor
public final class WorkspaceService: ObservableObject {
    public static let shared = WorkspaceService()

    @Published public private(set) var activeSpaceIndex: Int = 1
    @Published public private(set) var spacesCount: Int = 4
    @Published public private(set) var workspaces: [WorkspaceInfo] = []
    @Published public private(set) var currentWorkspaceApps: [WorkspaceAppItem] = []
    @Published public private(set) var isOmniWMRunning: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var skyLightHandle: UnsafeMutableRawPointer?
    private var cgsMainConnectionID: (@convention(c) () -> Int32)?
    private var cgsCopyManagedDisplaySpaces: (@convention(c) (Int32) -> CFArray?)?

    // OmniWM background process management
    private var omniWMProcess: Process?
    private var omniWMPipe: Pipe?
    private var omniWMBuffer: String = ""
    private var omniWMCtlPath: String?

    // Cached OmniWM state for atomic merging
    private var cachedWorkspaceDetails: [OmniWMWorkspaceDetail] = []
    private var cachedWindows: [OmniWMWindowItem] = []

    private init() {
        setupSkyLight()
        setupOmniWM()
        if !isOmniWMRunning {
            updateSpaces()
            updateWorkspaceApps()
        }
        registerObservers()
    }

    // MARK: - OmniWM Integration

    private func setupOmniWM() {
        Self.ensureOmniWMIPCEnabled()
        omniWMCtlPath = Self.findOmniWMCtl()
        checkAndStartOmniWM()
    }

    private static func findOmniWMCtl() -> String? {
        let candidates = [
            "/Applications/OmniWM.app/Contents/MacOS/omniwmctl",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/OmniWM.app/Contents/MacOS/omniwmctl").path,
            "/usr/local/bin/omniwmctl",
            "/opt/homebrew/bin/omniwmctl"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private static func ensureOmniWMIPCEnabled() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let settingsURL = home.appendingPathComponent(".config/omniwm/settings.toml")
        guard FileManager.default.fileExists(atPath: settingsURL.path),
              let content = try? String(contentsOf: settingsURL, encoding: .utf8) else {
            return
        }
        if content.contains("ipcEnabled = false") {
            let updated = content.replacingOccurrences(of: "ipcEnabled = false", with: "ipcEnabled = true")
            try? updated.write(to: settingsURL, atomically: true, encoding: .utf8)
        }
    }

    public func checkAndStartOmniWM() {
        guard let ctl = omniWMCtlPath,
              FileManager.default.isExecutableFile(atPath: ctl) else {
            return
        }

        let isRunning = NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier == "com.barut.OmniWM" || $0.localizedName == "OmniWM"
        })

        if isRunning {
            self.isOmniWMRunning = true
            fetchOmniWMStateSynchronously()
            startOmniWMSubscription()
        } else {
            stopOmniWMSubscription()
        }
    }

    private func runOmniWMQueryRaw(_ argument: String) -> Data? {
        guard let ctl = omniWMCtlPath, FileManager.default.isExecutableFile(atPath: ctl) else { return nil }
        let task = Process()
        task.launchPath = ctl
        task.arguments = ["query", argument, "--json"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return data
        } catch {
            return nil
        }
    }

    /// Fetches initial OmniWM state via fast synchronous queries (~20ms total).
    private func fetchOmniWMStateSynchronously() {
        var activeNum = self.activeSpaceIndex

        if let actData = runOmniWMQueryRaw("active-workspace"),
           let actMsg = try? JSONDecoder().decode(OmniWMAnyMessage.self, from: actData),
           let num = actMsg.result?.payload?.workspace?.number {
            activeNum = num
        }

        if let wsData = runOmniWMQueryRaw("workspaces"),
           let wsMsg = try? JSONDecoder().decode(OmniWMAnyMessage.self, from: wsData),
           let wsList = wsMsg.result?.payload?.workspaces {
            self.cachedWorkspaceDetails = wsList
        }

        if let winData = runOmniWMQueryRaw("windows"),
           let winMsg = try? JSONDecoder().decode(OmniWMAnyMessage.self, from: winData),
           let winList = winMsg.result?.payload?.windows {
            self.cachedWindows = winList
        }

        updateWorkspacesWithWindows(
            workspaceDetails: self.cachedWorkspaceDetails,
            windows: self.cachedWindows,
            activeNumber: activeNum
        )
    }

    private func startOmniWMSubscription() {
        guard omniWMProcess == nil, let ctl = omniWMCtlPath else { return }

        let task = Process()
        task.launchPath = ctl
        task.arguments = ["subscribe", "active-workspace,windows-changed,workspace-bar", "--format", "ndjson"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        task.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleOmniWMProcessTerminated()
            }
        }

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.processOmniWMStreamChunk(chunk)
            }
        }

        do {
            try task.run()
            self.omniWMProcess = task
            self.omniWMPipe = pipe
            self.isOmniWMRunning = true
        } catch {
            self.omniWMProcess = nil
            self.omniWMPipe = nil
        }
    }

    private func handleOmniWMProcessTerminated() {
        self.omniWMProcess = nil
        self.omniWMPipe = nil
        self.omniWMBuffer = ""

        let stillRunning = NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier == "com.barut.OmniWM" || $0.localizedName == "OmniWM"
        })

        if stillRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.checkAndStartOmniWM()
            }
        } else {
            self.isOmniWMRunning = false
            updateSpaces()
            updateWorkspaceApps()
        }
    }

    private func processOmniWMStreamChunk(_ chunk: String) {
        omniWMBuffer += chunk
        while let newlineIndex = omniWMBuffer.firstIndex(of: "\n") {
            let line = String(omniWMBuffer[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            omniWMBuffer = String(omniWMBuffer[omniWMBuffer.index(after: newlineIndex)...])

            if !line.isEmpty, let data = line.data(using: .utf8) {
                if let message = try? JSONDecoder().decode(OmniWMAnyMessage.self, from: data) {
                    handleOmniWMMessage(message)
                }
            }
        }
    }

    private func handleOmniWMMessage(_ message: OmniWMAnyMessage) {
        guard let result = message.result else { return }

        if message.channel == "active-workspace" || result.kind == "active-workspace" {
            if let ws = result.payload?.workspace {
                let newActive = ws.number
                self.activeSpaceIndex = newActive
                // Update workspace isCurrent states
                self.workspaces = self.workspaces.map { item in
                    WorkspaceInfo(
                        id: item.id,
                        number: item.number,
                        name: item.name,
                        isCurrent: item.number == newActive,
                        apps: item.apps
                    )
                }
                if let currentWs = self.workspaces.first(where: { $0.number == newActive }) {
                    self.currentWorkspaceApps = currentWs.apps
                }
            }
        } else if message.channel == "windows-changed" || result.kind == "windows" {
            if let windows = result.payload?.windows {
                self.cachedWindows = windows
                updateWorkspacesWithWindows(
                    workspaceDetails: self.cachedWorkspaceDetails,
                    windows: self.cachedWindows,
                    activeNumber: self.activeSpaceIndex
                )
            }
        } else if message.channel == "workspace-bar" || result.kind == "workspace-bar" {
            if let monitors = result.payload?.monitors {
                var newDetails: [OmniWMWorkspaceDetail] = []
                for monitor in monitors {
                    for ws in monitor.workspaces ?? [] {
                        newDetails.append(OmniWMWorkspaceDetail(
                            id: ws.id,
                            number: ws.number,
                            displayName: ws.displayName,
                            rawName: ws.rawName,
                            isCurrent: ws.number == self.activeSpaceIndex,
                            isFocused: ws.number == self.activeSpaceIndex
                        ))
                    }
                }
                if !newDetails.isEmpty {
                    var seen = Set<Int>()
                    var unique: [OmniWMWorkspaceDetail] = []
                    for d in newDetails where !seen.contains(d.number) {
                        seen.insert(d.number)
                        unique.append(d)
                    }
                    self.cachedWorkspaceDetails = unique.sorted(by: { $0.number < $1.number })
                    updateWorkspacesWithWindows(
                        workspaceDetails: self.cachedWorkspaceDetails,
                        windows: self.cachedWindows,
                        activeNumber: self.activeSpaceIndex
                    )
                }
            }
        }
    }

    /// Combines workspace details and windows into accurate per-workspace app lists.
    private func updateWorkspacesWithWindows(
        workspaceDetails: [OmniWMWorkspaceDetail],
        windows: [OmniWMWindowItem],
        activeNumber: Int
    ) {
        let runningApps = NSWorkspace.shared.runningApplications
        let runningByBundle = Dictionary(grouping: runningApps, by: { $0.bundleIdentifier ?? "" })

        var details = workspaceDetails
        if details.isEmpty {
            // Default 1...4 if not yet loaded
            details = (1...4).map {
                OmniWMWorkspaceDetail(id: "ws-\($0)", number: $0, displayName: "\($0)", rawName: "\($0)", isCurrent: $0 == activeNumber, isFocused: $0 == activeNumber)
            }
        }

        var resultWorkspaces: [WorkspaceInfo] = []

        for ws in details.sorted(by: { $0.number < $1.number }) {
            let wsWindows = windows.filter { $0.workspace?.number == ws.number }

            var wsApps: [WorkspaceAppItem] = []
            var seenBundleIDs = Set<String>()

            for win in wsWindows {
                let bundleID = win.app?.bundleId ?? ""
                let rawName = win.app?.name ?? "App"
                let key = bundleID.isEmpty ? rawName : bundleID

                // Deduplicate distinct apps in the workspace pill list
                if seenBundleIDs.contains(key) {
                    continue
                }
                seenBundleIDs.insert(key)

                let appMatches = runningByBundle[bundleID] ?? []
                let matchingApp = appMatches.first
                let pid = win.pid ?? matchingApp?.processIdentifier ?? 0
                let name = matchingApp?.localizedName ?? rawName
                let path = matchingApp?.bundleURL?.path ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path ?? ""
                let isActive = (win.isFocused == true)

                wsApps.append(WorkspaceAppItem(
                    pid: pid,
                    name: name,
                    bundleID: bundleID,
                    path: path,
                    isActive: isActive,
                    omniWMWindowID: win.id
                ))
            }

            let isCurrent = (ws.number == activeNumber)
            resultWorkspaces.append(WorkspaceInfo(
                id: ws.id,
                number: ws.number,
                name: ws.displayName,
                isCurrent: isCurrent,
                apps: wsApps
            ))
        }

        self.activeSpaceIndex = activeNumber
        self.workspaces = resultWorkspaces
        self.spacesCount = resultWorkspaces.count
        if let current = resultWorkspaces.first(where: { $0.number == activeNumber }) {
            self.currentWorkspaceApps = current.apps
        } else {
            self.currentWorkspaceApps = []
        }
    }

    private func runOmniWMCommand(_ args: [String]) {
        guard let ctl = omniWMCtlPath, FileManager.default.isExecutableFile(atPath: ctl) else { return }
        Task.detached {
            let task = Process()
            task.launchPath = ctl
            task.arguments = args
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
            task.waitUntilExit()
        }
    }

    private func stopOmniWMSubscription() {
        if let proc = omniWMProcess, proc.isRunning {
            proc.terminate()
        }
        omniWMProcess = nil
        omniWMPipe = nil
        omniWMBuffer = ""
        isOmniWMRunning = false
    }

    // MARK: - Native SkyLight Setup

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

        // Listen for active workspace changes (SkyLight fallback)
        wsCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isOmniWMRunning else { return }
                self.updateSpaces()
                self.updateWorkspaceApps()
            }
            .store(in: &cancellables)

        // Listen for active app changes
        wsCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isOmniWMRunning else { return }
                self.updateWorkspaceApps()
            }
            .store(in: &cancellables)

        // Listen for launches and terminations
        wsCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self else { return }
                if let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   app.bundleIdentifier == "com.barut.OmniWM" || app.localizedName == "OmniWM" {
                    self.checkAndStartOmniWM()
                } else if !self.isOmniWMRunning {
                    self.updateWorkspaceApps()
                }
            }
            .store(in: &cancellables)

        wsCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self else { return }
                if let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   app.bundleIdentifier == "com.barut.OmniWM" || app.localizedName == "OmniWM" {
                    self.stopOmniWMSubscription()
                    self.updateSpaces()
                    self.updateWorkspaceApps()
                } else if !self.isOmniWMRunning {
                    self.updateWorkspaceApps()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Native Spaces & Windows Updating

    /// Queries the current space index and count via SkyLight CGS API.
    public func updateSpaces() {
        if isOmniWMRunning { return }

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
        if isOmniWMRunning { return }

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

    // MARK: - Workspace Control

    /// Switches to the specified workspace number.
    public func switchSpace(_ number: Int) {
        self.activeSpaceIndex = number

        if isOmniWMRunning {
            // Optimistically update UI
            if !self.workspaces.isEmpty {
                self.workspaces = self.workspaces.map { item in
                    WorkspaceInfo(
                        id: item.id,
                        number: item.number,
                        name: item.name,
                        isCurrent: item.number == number,
                        apps: item.apps
                    )
                }
                if let currentWs = self.workspaces.first(where: { $0.number == number }) {
                    self.currentWorkspaceApps = currentWs.apps
                } else {
                    self.currentWorkspaceApps = []
                }
            }
            runOmniWMCommand(["command", "switch-workspace", "anywhere", "\(number)"])
            return
        }

        // Native SkyLight Control key emulation
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
            guard let self = self, !self.isOmniWMRunning else { return }
            self.updateSpaces()
            self.updateWorkspaceApps()
        }
    }

    /// Activates the given workspace application.
    public func activate(app: WorkspaceAppItem) {
        if isOmniWMRunning, let winId = app.omniWMWindowID, !winId.isEmpty {
            runOmniWMCommand(["window", "focus", winId])
        }

        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == app.pid && app.pid != 0 }) {
            running.activate()
        } else if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == app.bundleID && !app.bundleID.isEmpty }) {
            running.activate()
        }

        if !isOmniWMRunning {
            updateWorkspaceApps()
        }
    }
}
