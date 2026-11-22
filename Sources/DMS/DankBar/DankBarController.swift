import AppKit
import SwiftUI
import Combine
import CoreGraphics
import DMSCore

/// Multi-instance DankBar layout engine and window manager.
/// Manages independent ShellPanel instances across all connected monitors (NSScreen),
/// per-screen Mac notch detection, and all 4 screen edges (Top, Bottom, Left, Right) per docs/spec/19-bar-core.md.
@MainActor
public final class DankBarController {
    public static let shared = DankBarController()

    // Panel state is keyed by BarPanelKey.rawKey ("<displayID>|<position>|<configID>"),
    // where displayID is the stable CGDirectDisplayID — never the volatile
    // NSScreen.screens array index, which changes on monitor reorder/hot-plug/wake.
    public private(set) var panels: [String: ShellPanel] = [:]
    private var hostingViews: [String: NSHostingView<DankBarView>] = [:]
    public private(set) var screenNotchGeometries: [CGDirectDisplayID: ScreenNotchGeometry] = [:]
    public private(set) var isVisible = true
    private var autoHideRevealed: [String: Bool] = [:]
    private var hoverTasks: [String: Task<Void, Never>] = [:]
    private var mouseMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Smart Auto-Hide State (Ported from Tralphium)
    public private(set) var fullscreenScreens: Set<CGDirectDisplayID> = []
    public private(set) var obstructedBarKeys: Set<String> = []
    private var fullscreenTimer: Timer?
    private var fullscreenCheckTasks: [Task<Void, Never>] = []
    private var localMouseMonitor: Any?

    public static let barHeight: CGFloat = 48
    public static let verticalBarWidth: CGFloat = 54

    public var panel: ShellPanel {
        // Primary panel for backward compatibility with existing single-panel consumers.
        // Prefer the bar on the main display (stable CGDirectDisplayID), then any panel.
        let mainDisplayID = CGMainDisplayID()
        if let primary = panels.first(where: { BarPanelKey(rawKey: $0.key)?.displayID == mainDisplayID })?.value {
            return primary
        }
        if let primary = panels.values.first {
            return primary
        }
        let fallback = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        return fallback
    }

    private init() {
        setupFullscreenObservers()
        setupScreenChangeObserver()
        setupConfigObserver()
        checkFullscreenState()
        reposition()
        scheduleFullscreenChecks()
    }

    /// Exact bar-config lookup for a panel key (see `BarPanelKey.rawKey`).
    /// Parses the key structurally, so config ids that are prefixes of one another
    /// (or contain underscores/special characters) can never collide.
    private func barConfig(forKey key: String, configs: [BarConfig]) -> BarConfig? {
        guard let configID = BarPanelKey(rawKey: key)?.configID else { return nil }
        return configs.first(where: { $0.id == configID })
    }

    /// Active bar configs for a screen. When the user pinned bars to specific screens
    /// (explicit screenPreferences without "all"), screens matching no config get NO bar.
    /// A config with empty screenPreferences defaults to the primary display —
    /// `screen.isPrimaryDisplay` (stable CGDirectDisplayID comparison), falling back
    /// to array index 0 when the display id cannot be determined.
    private func activeBarConfigs(for screen: NSScreen, screenIndex: Int, screenName: String, configs: [BarConfig]) -> [BarConfig] {
        let isPrimary = screen.isPrimaryDisplay || screenIndex == 0
        let matching = configs.filter { config in
            config.screenPreferences.contains("all") ||
            config.screenPreferences.contains(screenName) ||
            (config.screenPreferences.isEmpty && isPrimary)
        }
        if !matching.isEmpty { return matching }
        let anyExplicit = configs.contains { !$0.screenPreferences.isEmpty && !$0.screenPreferences.contains("all") }
        return anyExplicit ? [] : [configs.first ?? .default]
    }

    public func show() {
        isVisible = true
        let configs = ConfigStore.shared.config.barConfigs
        for (key, panel) in panels {
            let displayID = BarPanelKey(rawKey: key)?.displayID ?? 0
            let isScreenFS = fullscreenScreens.contains(displayID)
            let isObstructed = obstructedBarKeys.contains(key) || isScreenFS
            let barConfig = barConfig(forKey: key, configs: configs) ?? .default
            if (barConfig.smartAutoHide && isObstructed) || isScreenFS {
                continue
            }
            panel.orderFrontRegardless()
        }
    }

    public func hide() {
        isVisible = false
        for panel in panels.values {
            panel.orderOut(nil)
        }
    }

    public func updateBarFrame() {
        reposition()
    }

    public func reposition() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let configs = ConfigStore.shared.config.barConfigs
        var activeKeys = Set<String>()
        var anyAutoHide = false

        for (screenIndex, screen) in screens.enumerated() {
            let screenName = screen.localizedName
            let activeConfigs = activeBarConfigs(for: screen, screenIndex: screenIndex, screenName: screenName, configs: configs)

            for barConfig in activeConfigs {
                let key = BarPanelKey(displayID: screen.displayID, configID: barConfig.id, position: barConfig.position).rawKey
                activeKeys.insert(key)

                if barConfig.autoHide {
                    anyAutoHide = true
                }

                let notch = screen.extractNotchGeometry(barConfig: barConfig)
                screenNotchGeometries[screen.displayID] = notch

                let baseThickness = CGFloat(barConfig.thickness > 0 ? barConfig.thickness : (barConfig.isVertical ? 54 : 48))
                let isTopNotched = (barConfig.position.lowercased() == "top" && notch.hasNotch && barConfig.adaptToNotch)
                let thickness = isTopNotched ? max(baseThickness, CGFloat(notch.notchHeight) + 4) : baseThickness
                let margin = isTopNotched ? max(4.0, CGFloat(barConfig.margin) * 0.5) : CGFloat(barConfig.margin)
                let screenFrame = screen.frame

                let isRevealed = !barConfig.autoHide || (autoHideRevealed[key] ?? false)
                let peekAmount: CGFloat = 2.0

                let frame: NSRect
                let hMargin = barConfig.gothCorners ? 0.0 : margin
                let vMargin = barConfig.gothCorners ? 0.0 : margin

                switch barConfig.position.lowercased() {
                case "top":
                    let isIslandStyle = barConfig.backgroundStyle.lowercased() == "island" || ConfigStore.shared.config.islandSettings.instance == .mainBar
                    let topMargin = (barConfig.gothCorners || (isTopNotched && !isIslandStyle)) ? 0.0 : margin
                    let normalY = screenFrame.maxY - thickness - topMargin
                    let hiddenY = screenFrame.maxY - peekAmount
                    frame = NSRect(
                        x: screenFrame.minX + hMargin,
                        y: isRevealed ? normalY : hiddenY,
                        width: max(100, screenFrame.width - (hMargin * 2)),
                        height: thickness
                    )
                case "left":
                    let leftMargin = barConfig.gothCorners ? 0.0 : margin
                    let normalX = screenFrame.minX + leftMargin
                    let hiddenX = screenFrame.minX - thickness + peekAmount
                    frame = NSRect(
                        x: isRevealed ? normalX : hiddenX,
                        y: screenFrame.minY + vMargin,
                        width: thickness,
                        height: max(100, screenFrame.height - (vMargin * 2))
                    )
                case "right":
                    let rightMargin = barConfig.gothCorners ? 0.0 : margin
                    let normalX = screenFrame.maxX - thickness - rightMargin
                    let hiddenX = screenFrame.maxX - peekAmount
                    frame = NSRect(
                        x: isRevealed ? normalX : hiddenX,
                        y: screenFrame.minY + vMargin,
                        width: thickness,
                        height: max(100, screenFrame.height - (vMargin * 2))
                    )
                case "bottom":
                    fallthrough
                default:
                    let bottomMargin = barConfig.gothCorners ? 0.0 : margin
                    let normalY = screenFrame.minY + bottomMargin
                    let hiddenY = screenFrame.minY - thickness + peekAmount
                    frame = NSRect(
                        x: screenFrame.minX + hMargin,
                        y: isRevealed ? normalY : hiddenY,
                        width: max(100, screenFrame.width - (hMargin * 2)),
                        height: thickness
                    )
                }

                let panel: ShellPanel
                if let existing = panels[key] {
                    panel = existing
                } else {
                    panel = ShellPanel(
                        contentRect: frame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered,
                        defer: false
                    )
                    panel.level = .statusBar
                    panels[key] = panel
                }

                let rootView = DankBarView(
                    barConfig: barConfig,
                    notchGeometry: notch,
                    screenIndex: screenIndex
                )
                if let existingHost = hostingViews[key] {
                    existingHost.rootView = rootView
                } else {
                    let host = NSHostingView(rootView: rootView)
                    panel.contentView = host
                    hostingViews[key] = host
                }

                let isScreenFS = fullscreenScreens.contains(screen.displayID)
                let isObstructed = obstructedBarKeys.contains(key) || isScreenFS
                if (barConfig.smartAutoHide && isObstructed) || isScreenFS {
                    panel.orderOut(nil)
                    continue
                }

                // When auto-hide is enabled and the bar is hidden, the 2pt peek strip must not
                // swallow clicks meant for the screen edge underneath it.
                if barConfig.autoHide {
                    panel.ignoresMouseEvents = !isRevealed
                }
                panel.alphaValue = isRevealed ? 1.0 : 0.02
                panel.setFrame(frame, display: true)
                if isVisible {
                    panel.orderFrontRegardless()
                }
            }
        }

        // Clean up panels and hosting views for disconnected monitors or removed bar instances
        for (key, panel) in panels where !activeKeys.contains(key) {
            panel.orderOut(nil)
            panels.removeValue(forKey: key)
            hostingViews.removeValue(forKey: key)
            autoHideRevealed.removeValue(forKey: key)
            hoverTasks[key]?.cancel()
            hoverTasks.removeValue(forKey: key)
        }

        updateAutoHideMonitor(enabled: anyAutoHide)
    }

    // MARK: - Smart Auto-Hide & Fullscreen Detection (Spec 19 / Ported from Tralphium)

    public func isScreenFullscreen(displayID: CGDirectDisplayID) -> Bool {
        fullscreenScreens.contains(displayID)
    }

    /// Compatibility helper for callers still holding a volatile `NSScreen.screens`
    /// array index: resolves the index to the screen's stable display id first.
    public func isScreenFullscreen(index: Int) -> Bool {
        let screens = NSScreen.screens
        guard index >= 0, index < screens.count else { return false }
        return fullscreenScreens.contains(screens[index].displayID)
    }

    public var isAppFullscreen: Bool {
        !fullscreenScreens.isEmpty
    }

    private func setupFullscreenObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleFullscreenChecks()
            }
        }

        wsCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleFullscreenChecks()
            }
        }

        wsCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleFullscreenChecks()
            }
        }

        // Periodic heartbeat check to guarantee bar reappears when exiting fullscreen or windows move.
        // Throttled: skipped entirely when no bar uses smartAutoHide and no fullscreen Space is active.
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let configs = ConfigStore.shared.config.barConfigs
                let anySmartAutoHide = configs.contains { $0.smartAutoHide }
                if !anySmartAutoHide && self.fullscreenScreens.isEmpty { return }
                self.checkFullscreenState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        fullscreenTimer = timer
    }

    private func scheduleFullscreenChecks() {
        // Cancel the previous burst before spawning a new one so stale delayed checks
        // can never fire after a newer state was already computed.
        for task in fullscreenCheckTasks { task.cancel() }
        fullscreenCheckTasks.removeAll()
        checkFullscreenState()
        for delay in [0.2, 0.4, 0.7, 1.0, 1.5] {
            let task = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.checkFullscreenState()
            }
            fullscreenCheckTasks.append(task)
        }
    }

    public func checkFullscreenState() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        var newFullscreenScreens = Set<CGDirectDisplayID>()
        var newObstructedBarKeys = Set<String>()

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windowList = (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []

        let myPID = ProcessInfo.processInfo.processIdentifier
        var activePIDs = Set<pid_t>()

        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier,
           frontApp.processIdentifier != myPID {
            activePIDs.insert(frontApp.processIdentifier)
        } else if let activeApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.isActive && $0.bundleIdentifier != Bundle.main.bundleIdentifier && $0.processIdentifier != myPID
        }) {
            activePIDs.insert(activeApp.processIdentifier)
        }

        // Fallback: If activePIDs is empty, find the frontmost Layer 0 application window
        if activePIDs.isEmpty {
            for win in windowList {
                guard let winPID = win[kCGWindowOwnerPID as String] as? pid_t, winPID != myPID else { continue }
                guard let layer = win[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
                let owner = win[kCGWindowOwnerName as String] as? String ?? ""
                let lowerOwner = owner.lowercased()
                if lowerOwner.contains("window server") || lowerOwner.contains("menubaragent") || lowerOwner.contains("dock") {
                    continue
                }
                if let bounds = win[kCGWindowBounds as String] as? [String: CGFloat],
                   let w = bounds["Width"], let h = bounds["Height"],
                   w > 100 && h > 100 {
                    activePIDs.insert(winPID)
                    break
                }
            }
        }

        let configs = ConfigStore.shared.config.barConfigs
        let primaryScreen = screens.first!
        let primaryHeight = primaryScreen.frame.height

        for (screenIndex, screen) in screens.enumerated() {
            let screenCGY = Double(primaryHeight - screen.frame.maxY)
            let screenCGX = Double(screen.frame.minX)
            let screenW = Double(screen.frame.width)
            let screenH = Double(screen.frame.height)
            let screenVisH = Double(screen.visibleFrame.height)

            // Native fullscreen presentation options only apply to the screen that actually
            // hosts the fullscreen window (the main screen, compared by stable display id)
            // — never to every other monitor.
            var isFS = screen.isPrimaryDisplay && NSApp.currentSystemPresentationOptions.contains(.fullScreen)
            if !isFS {
                for win in windowList {
                    guard let layer = win[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
                    guard let winPID = win[kCGWindowOwnerPID as String] as? pid_t, winPID != myPID else { continue }
                    guard let bounds = win[kCGWindowBounds as String] as? [String: CGFloat],
                          let w = bounds["Width"], let h = bounds["Height"],
                          let winX = bounds["X"], let winY = bounds["Y"] else { continue }

                    // Any window strictly spanning this physical screen (games, full-screen video players)
                    if SmartAutoHideSolver.isWindowStrictFullscreen(
                        windowX: Double(winX),
                        windowY: Double(winY),
                        windowWidth: Double(w),
                        windowHeight: Double(h),
                        screenWidth: screenW,
                        screenHeight: screenH,
                        screenCGX: screenCGX,
                        screenCGY: screenCGY,
                        tolerance: 10.0
                    ) {
                        isFS = true
                        break
                    }

                    // Active application covering the display — strict fullscreen only: the window
                    // must span the FULL PHYSICAL height (screenH), not just the visible height, so
                    // normal maximized or OmniWM-tiled windows never hide the bar when
                    // smartAutoHide == false. The X-axis bounds check ensures a fullscreen window
                    // on Monitor 1 never marks Monitor 2 as fullscreen.
                    if activePIDs.contains(winPID) {
                        let matchesX = abs(Double(winX) - screenCGX) <= 15.0
                        let touchesBottom = (Double(winY) + Double(h)) >= (screenCGY + screenH - 10.0)
                        let isFullWidth = Double(w) >= (screenW - 10.0)
                        let isStrictFullHeight = Double(h) >= (screenH - 10.0)
                        if matchesX && isFullWidth && isStrictFullHeight && touchesBottom {
                            isFS = true
                            break
                        }
                    }
                }
            }

            if isFS {
                newFullscreenScreens.insert(screen.displayID)
            }

            // Per-bar obstruction evaluation for active configs on this screen
            let screenName = screen.localizedName
            let activeConfigs = activeBarConfigs(for: screen, screenIndex: screenIndex, screenName: screenName, configs: configs)

            for barConfig in activeConfigs {
                let key = BarPanelKey(displayID: screen.displayID, configID: barConfig.id, position: barConfig.position).rawKey
                if isFS {
                    newObstructedBarKeys.insert(key)
                    continue
                }

                let thickness = CGFloat(barConfig.thickness > 0 ? barConfig.thickness : (barConfig.isVertical ? 54 : 48))
                let margin = CGFloat(barConfig.margin)
                let barCGX: Double
                let barCGY: Double
                let barCGWidth: Double
                let barCGHeight: Double

                switch barConfig.position.lowercased() {
                case "top":
                    barCGX = screenCGX + Double(margin)
                    barCGY = screenCGY + Double(margin)
                    barCGWidth = max(100.0, screenW - Double(margin * 2))
                    barCGHeight = Double(thickness)
                case "left":
                    barCGX = screenCGX + Double(margin)
                    barCGY = screenCGY + Double(margin)
                    barCGWidth = Double(thickness)
                    barCGHeight = max(100.0, screenH - Double(margin * 2))
                case "right":
                    barCGX = screenCGX + screenW - Double(thickness) - Double(margin)
                    barCGY = screenCGY + Double(margin)
                    barCGWidth = Double(thickness)
                    barCGHeight = max(100.0, screenH - Double(margin * 2))
                case "bottom":
                    fallthrough
                default:
                    barCGX = screenCGX + Double(margin)
                    barCGY = screenCGY + screenH - Double(thickness) - Double(margin)
                    barCGWidth = max(100.0, screenW - Double(margin * 2))
                    barCGHeight = Double(thickness)
                }

                for win in windowList {
                    guard let layer = win[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
                    guard let winPID = win[kCGWindowOwnerPID as String] as? pid_t, winPID != myPID else { continue }
                    guard activePIDs.contains(winPID) else { continue }
                    guard let bounds = win[kCGWindowBounds as String] as? [String: CGFloat],
                          let w = bounds["Width"], let h = bounds["Height"],
                          let winX = bounds["X"], let winY = bounds["Y"] else { continue }

                    if SmartAutoHideSolver.isWindowObstructing(
                        windowX: Double(winX),
                        windowY: Double(winY),
                        windowWidth: Double(w),
                        windowHeight: Double(h),
                        screenWidth: screenW,
                        screenHeight: screenH,
                        screenVisibleHeight: screenVisH,
                        screenCGX: screenCGX,
                        screenCGY: screenCGY,
                        barCGX: barCGX,
                        barCGY: barCGY,
                        barCGWidth: barCGWidth,
                        barCGHeight: barCGHeight,
                        tolerance: 4.0
                    ) {
                        newObstructedBarKeys.insert(key)
                        break
                    }
                }
            }
        }

        let changed = (newFullscreenScreens != fullscreenScreens || newObstructedBarKeys != obstructedBarKeys)
        if changed {
            fullscreenScreens = newFullscreenScreens
            obstructedBarKeys = newObstructedBarKeys
            reposition()
        } else {
            // Self-healing synchronization: if panel state disagrees with obstruction state, reposition
            var needsReposition = false
            for (key, panel) in panels {
                let shouldBeHidden = obstructedBarKeys.contains(key)
                let barConfig = barConfig(forKey: key, configs: configs) ?? .default
                if barConfig.smartAutoHide {
                    if shouldBeHidden && panel.isVisible {
                        needsReposition = true
                        break
                    } else if !shouldBeHidden && !panel.isVisible && isVisible && !barConfig.autoHide {
                        needsReposition = true
                        break
                    }
                }
            }
            if needsReposition {
                reposition()
            }
        }
    }

    public func isFrontmostAppFullscreen(on targetScreen: NSScreen? = nil) -> Bool {
        if NSApp.currentSystemPresentationOptions.contains(.fullScreen) {
            if let targetScreen, let main = NSScreen.main {
                if targetScreen == main { return true }
            } else {
                return true
            }
        }

        let myPID = ProcessInfo.processInfo.processIdentifier
        var activePIDs = Set<pid_t>()
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier,
           frontApp.processIdentifier != myPID {
            activePIDs.insert(frontApp.processIdentifier)
        } else if let activeApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.isActive && $0.bundleIdentifier != Bundle.main.bundleIdentifier && $0.processIdentifier != myPID
        }) {
            activePIDs.insert(activeApp.processIdentifier)
        }

        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return false }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        if activePIDs.isEmpty {
            for win in windowList {
                guard let winPID = win[kCGWindowOwnerPID as String] as? pid_t, winPID != myPID else { continue }
                guard let layer = win[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
                let owner = win[kCGWindowOwnerName as String] as? String ?? ""
                let lower = owner.lowercased()
                if lower.contains("window server") || lower.contains("menubaragent") || lower.contains("dock") {
                    continue
                }
                if let bounds = win[kCGWindowBounds as String] as? [String: CGFloat],
                   let w = bounds["Width"], let h = bounds["Height"],
                   w > 100 && h > 100 {
                    activePIDs.insert(winPID)
                    break
                }
            }
        }

        let primaryScreen = NSScreen.screens.first ?? screen
        let primaryHeight = primaryScreen.frame.height
        let screenCGY = primaryHeight - screen.frame.maxY
        let screenCGX = screen.frame.minX

        for win in windowList {
            guard let layer = win[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let winPID = win[kCGWindowOwnerPID as String] as? pid_t, winPID != myPID else { continue }
            guard let bounds = win[kCGWindowBounds as String] as? [String: CGFloat],
                  let w = bounds["Width"], let h = bounds["Height"],
                  let winX = bounds["X"], let winY = bounds["Y"] else { continue }

            if SmartAutoHideSolver.isWindowStrictFullscreen(
                windowX: Double(winX),
                windowY: Double(winY),
                windowWidth: Double(w),
                windowHeight: Double(h),
                screenWidth: Double(screen.frame.width),
                screenHeight: Double(screen.frame.height),
                screenCGX: Double(screenCGX),
                screenCGY: Double(screenCGY),
                tolerance: 10.0
            ) {
                return true
            }

            if activePIDs.contains(winPID) {
                // Strict fullscreen only (full physical height + X-axis bounds match), so a
                // fullscreen window on one monitor never reports another monitor as fullscreen
                // and maximized/tiled windows don't count.
                let matchesX = abs(Double(winX) - Double(screenCGX)) <= 15.0
                let touchesBottom = (Double(winY) + Double(h)) >= (Double(screenCGY) + Double(screen.frame.height) - 10.0)
                let isFullWidth = Double(w) >= (Double(screen.frame.width) - 10.0)
                let isStrictFullHeight = Double(h) >= (Double(screen.frame.height) - 10.0)
                if matchesX && isFullWidth && isStrictFullHeight && touchesBottom {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Auto-Hide Hover State Machine (Spec 19 BARC-020..024)

    private func updateAutoHideMonitor(enabled: Bool) {
        if enabled && mouseMonitor == nil {
            let handler: (NSEvent) -> NSEvent? = { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.evaluateAutoHideHover()
                }
                return event
            }
            // Local monitor catches mouse movement over our own non-activating panels;
            // the global monitor catches movement everywhere else.
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: handler)
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.evaluateAutoHideHover()
                }
            }
        } else if !enabled {
            if let monitor = mouseMonitor {
                NSEvent.removeMonitor(monitor)
                mouseMonitor = nil
            }
            if let monitor = localMouseMonitor {
                NSEvent.removeMonitor(monitor)
                localMouseMonitor = nil
            }
        }
    }

    private func evaluateAutoHideHover() {
        let mouseLoc = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let configs = ConfigStore.shared.config.barConfigs

        // Pause collapse while any DMS popout / Control Center / Dash is open, so the bar
        // never slides away underneath an open panel.
        let overlayOpen = PopoutCoordinator.shared.anyPopoutVisible()
            || ControlCenterController.shared.isVisible
            || DashController.shared.isVisible

        // Evaluate EVERY auto-hide bar on EVERY monitor — not just the screen under the
        // cursor — so moving the mouse from Monitor 1 to Monitor 2 collapses Monitor 1's
        // revealed bar instead of leaving it stuck open forever.
        for (screenIndex, screen) in screens.enumerated() {
            let screenName = screen.localizedName
            let activeConfigs = activeBarConfigs(for: screen, screenIndex: screenIndex, screenName: screenName, configs: configs)

            for barConfig in activeConfigs where barConfig.autoHide {
                let isScreenFS = fullscreenScreens.contains(screen.displayID)
                if barConfig.smartAutoHide && isScreenFS {
                    continue
                }

                let key = BarPanelKey(displayID: screen.displayID, configID: barConfig.id, position: barConfig.position).rawKey
                let thickness = CGFloat(barConfig.thickness > 0 ? barConfig.thickness : (barConfig.isVertical ? 54 : 48))
                let triggerBand: CGFloat = (autoHideRevealed[key] ?? false) ? (thickness + 20) : 6.0
                let sf = screen.frame
                let mouseOnThisScreen = sf.insetBy(dx: -4, dy: -4).contains(mouseLoc)

                let inZone: Bool
                if !mouseOnThisScreen {
                    inZone = false
                } else {
                    switch barConfig.position.lowercased() {
                    case "top":
                        inZone = mouseLoc.y >= (sf.maxY - triggerBand)
                    case "left":
                        inZone = mouseLoc.x <= (sf.minX + triggerBand)
                    case "right":
                        inZone = mouseLoc.x >= (sf.maxX - triggerBand)
                    default:
                        inZone = mouseLoc.y <= (sf.minY + triggerBand)
                    }
                }

                let currentlyRevealed = autoHideRevealed[key] ?? false
                if inZone && !currentlyRevealed {
                    scheduleAutoHideTransition(key: key, reveal: true, delayMs: barConfig.hoverOpenDelayMs)
                } else if !inZone && currentlyRevealed && !overlayOpen {
                    scheduleAutoHideTransition(key: key, reveal: false, delayMs: barConfig.hoverCloseDelayMs)
                }
            }
        }
    }

    private func scheduleAutoHideTransition(key: String, reveal: Bool, delayMs: Int) {
        hoverTasks[key]?.cancel()
        hoverTasks[key] = Task { @MainActor [weak self] in
            let delayNs = UInt64(max(0, delayMs)) * 1_000_000
            if delayNs > 0 {
                try? await Task.sleep(nanoseconds: delayNs)
            }
            guard !Task.isCancelled, let self = self else { return }
            if (self.autoHideRevealed[key] ?? false) != reveal {
                self.autoHideRevealed[key] = reveal
                self.reposition()
            }
        }
    }

    private func setupScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Prune all per-display state for disconnected monitors. Everything is
                // keyed by stable CGDirectDisplayID, so anything whose display id is no
                // longer connected is stale: notch geometries, fullscreen flags,
                // obstruction keys, hover tasks, and orphaned panels.
                let connectedIDs = Set(NSScreen.screens.map(\.displayID))
                func isConnected(_ key: String) -> Bool {
                    guard let displayID = BarPanelKey(rawKey: key)?.displayID else { return false }
                    return connectedIDs.contains(displayID)
                }
                self.screenNotchGeometries = self.screenNotchGeometries.filter { connectedIDs.contains($0.key) }
                self.fullscreenScreens = self.fullscreenScreens.filter { connectedIDs.contains($0) }
                self.obstructedBarKeys = self.obstructedBarKeys.filter(isConnected)
                for key in self.hoverTasks.keys.filter({ !isConnected($0) }) {
                    self.hoverTasks[key]?.cancel()
                    self.hoverTasks.removeValue(forKey: key)
                }
                let stalePanelKeys = self.panels.keys.filter { !isConnected($0) }
                for key in stalePanelKeys {
                    self.panels[key]?.orderOut(nil)
                    self.panels.removeValue(forKey: key)
                    self.hostingViews.removeValue(forKey: key)
                    self.autoHideRevealed.removeValue(forKey: key)
                }
                self.scheduleFullscreenChecks()
                self.reposition()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleFullscreenChecks()
                self?.reposition()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleFullscreenChecks()
                self?.reposition()
            }
        }
    }

    private func setupConfigObserver() {
        ConfigStore.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleFullscreenChecks()
                self?.reposition()
            }
            .store(in: &cancellables)
    }
}
