import AppKit
import SwiftUI
import Combine
import DMSCore

/// Multi-instance DankBar layout engine and window manager.
/// Manages independent ShellPanel instances across all connected monitors (NSScreen),
/// per-screen Mac notch detection, and all 4 screen edges (Top, Bottom, Left, Right) per docs/spec/19-bar-core.md.
@MainActor
public final class DankBarController {
    public static let shared = DankBarController()

    public private(set) var panels: [String: ShellPanel] = [:]
    private var hostingViews: [String: NSHostingView<DankBarView>] = [:]
    public private(set) var screenNotchGeometries: [Int: ScreenNotchGeometry] = [:]
    public private(set) var isVisible = true
    private var autoHideRevealed: [String: Bool] = [:]
    private var hoverTasks: [String: Task<Void, Never>] = [:]
    private var mouseMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Smart Auto-Hide State (Ported from Tralphium)
    public private(set) var fullscreenScreens: Set<Int> = []
    public private(set) var obstructedBarKeys: Set<String> = []
    private var fullscreenTimer: Timer?

    public static let barHeight: CGFloat = 48
    public static let verticalBarWidth: CGFloat = 54

    public var panel: ShellPanel {
        // Primary panel for backward compatibility with existing single-panel consumers
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

    public func show() {
        isVisible = true
        let configs = ConfigStore.shared.config.barConfigs
        for (key, panel) in panels {
            let screenIndex = Int(key.split(separator: "_").first ?? "") ?? 0
            let isScreenFS = fullscreenScreens.contains(screenIndex)
            let isObstructed = obstructedBarKeys.contains(key) || isScreenFS
            let barConfig = configs.first(where: { key.contains($0.id) }) ?? .default
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
            let matchingConfigs = configs.filter { config in
                config.screenPreferences.contains("all") ||
                config.screenPreferences.contains(screenName) ||
                (config.screenPreferences.isEmpty && screenIndex == 0)
            }
            let activeConfigs = matchingConfigs.isEmpty ? [configs.first ?? .default] : matchingConfigs

            for barConfig in activeConfigs {
                let key = "\(screenIndex)_\(barConfig.id)_\(barConfig.position)"
                activeKeys.insert(key)

                if barConfig.autoHide {
                    anyAutoHide = true
                }

                let notch = screen.extractNotchGeometry(barConfig: barConfig)
                screenNotchGeometries[screenIndex] = notch

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

                let isScreenFS = fullscreenScreens.contains(screenIndex)
                let isObstructed = obstructedBarKeys.contains(key) || isScreenFS
                if (barConfig.smartAutoHide && isObstructed) || isScreenFS {
                    panel.orderOut(nil)
                    continue
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

    public func isScreenFullscreen(index: Int) -> Bool {
        fullscreenScreens.contains(index)
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

        // Periodic heartbeat check to guarantee bar reappears when exiting fullscreen or windows move
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkFullscreenState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        fullscreenTimer = timer
    }

    private func scheduleFullscreenChecks() {
        checkFullscreenState()
        for delay in [0.2, 0.4, 0.7, 1.0, 1.5] {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                self?.checkFullscreenState()
            }
        }
    }

    public func checkFullscreenState() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        var newFullscreenScreens = Set<Int>()
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

            var isFS = NSApp.currentSystemPresentationOptions.contains(.fullScreen)
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

                    // Active application covering the display (native or maximized under menu bar)
                    if activePIDs.contains(winPID) {
                        if SmartAutoHideSolver.isWindowFullscreen(
                            windowX: Double(winX),
                            windowY: Double(winY),
                            windowWidth: Double(w),
                            windowHeight: Double(h),
                            screenWidth: screenW,
                            screenHeight: screenH,
                            screenVisibleHeight: screenVisH,
                            screenCGX: screenCGX,
                            screenCGY: screenCGY,
                            tolerance: 10.0
                        ) {
                            isFS = true
                            break
                        }

                        // Tralphium-compatible bottom/screen coverage check
                        let touchesBottom = (Double(winY) + Double(h)) >= (screenCGY + screenH - 10.0)
                        let isFullWidth = Double(w) >= (screenW - 10.0)
                        let isFullHeight = Double(h) >= (screenVisH - 10.0) || Double(h) >= (screenH - 10.0)
                        if isFullWidth && isFullHeight && touchesBottom {
                            isFS = true
                            break
                        }
                    }
                }
            }

            if isFS {
                newFullscreenScreens.insert(screenIndex)
            }

            // Per-bar obstruction evaluation for active configs on this screen
            let screenName = screen.localizedName
            let matchingConfigs = configs.filter { config in
                config.screenPreferences.contains("all") ||
                config.screenPreferences.contains(screenName) ||
                (config.screenPreferences.isEmpty && screenIndex == 0)
            }
            let activeConfigs = matchingConfigs.isEmpty ? [configs.first ?? .default] : matchingConfigs

            for barConfig in activeConfigs {
                let key = "\(screenIndex)_\(barConfig.id)_\(barConfig.position)"
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
            DockController.shared.reposition()
        } else {
            // Self-healing synchronization: if panel state disagrees with obstruction state, reposition
            var needsReposition = false
            for (key, panel) in panels {
                let shouldBeHidden = obstructedBarKeys.contains(key)
                let barConfig = configs.first(where: { key.contains($0.id) }) ?? .default
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
                if SmartAutoHideSolver.isWindowFullscreen(
                    windowX: Double(winX),
                    windowY: Double(winY),
                    windowWidth: Double(w),
                    windowHeight: Double(h),
                    screenWidth: Double(screen.frame.width),
                    screenHeight: Double(screen.frame.height),
                    screenVisibleHeight: Double(screen.visibleFrame.height),
                    screenCGX: Double(screenCGX),
                    screenCGY: Double(screenCGY),
                    tolerance: 10.0
                ) {
                    return true
                }

                let touchesBottom = (Double(winY) + Double(h)) >= (Double(screenCGY) + Double(screen.frame.height) - 10.0)
                let isFullWidth = Double(w) >= (Double(screen.frame.width) - 10.0)
                let isFullHeight = Double(h) >= (Double(screen.visibleFrame.height) - 10.0) || Double(h) >= (Double(screen.frame.height) - 10.0)
                if isFullWidth && isFullHeight && touchesBottom {
                    return true
                }
            }
        }
        return false
    }

    public func isDockObstructed(screenIndex: Int, config: DockConfig, frame: NSRect) -> Bool {
        if fullscreenScreens.contains(screenIndex) { return true }
        let screens = NSScreen.screens
        guard screens.indices.contains(screenIndex) else { return false }
        let screen = screens[screenIndex]
        let primaryScreen = screens.first ?? screen
        let primaryHeight = primaryScreen.frame.height
        let dockCG = CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return false }

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

        for win in windowList {
            guard let layer = win[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let winPID = win[kCGWindowOwnerPID as String] as? pid_t, winPID != myPID else { continue }
            if !activePIDs.isEmpty && !activePIDs.contains(winPID) { continue }
            guard let bounds = win[kCGWindowBounds as String] as? [String: CGFloat],
                  let w = bounds["Width"], let h = bounds["Height"],
                  let winX = bounds["X"], let winY = bounds["Y"] else { continue }
            let winRect = CGRect(x: winX, y: winY, width: w, height: h)
            if SmartAutoHideSolver.isWindowOverlappingBar(windowBounds: winRect, barBounds: dockCG, tolerance: 15.0) {
                return true
            }
        }
        return false
    }

    // MARK: - Auto-Hide Hover State Machine (Spec 19 BARC-020..024)

    private func updateAutoHideMonitor(enabled: Bool) {
        if enabled && mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.evaluateAutoHideHover()
                }
            }
        } else if !enabled, let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    private func evaluateAutoHideHover() {
        let mouseLoc = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let configs = ConfigStore.shared.config.barConfigs

        for (screenIndex, screen) in screens.enumerated() {
            guard screen.frame.insetBy(dx: -4, dy: -4).contains(mouseLoc) else { continue }
            let screenName = screen.localizedName
            let matchingConfigs = configs.filter { config in
                config.screenPreferences.contains("all") ||
                config.screenPreferences.contains(screenName) ||
                (config.screenPreferences.isEmpty && screenIndex == 0)
            }
            let activeConfigs = matchingConfigs.isEmpty ? [configs.first ?? .default] : matchingConfigs

            for barConfig in activeConfigs where barConfig.autoHide {
                let isScreenFS = fullscreenScreens.contains(screenIndex)
                if barConfig.smartAutoHide && isScreenFS {
                    continue
                }

                let key = "\(screenIndex)_\(barConfig.id)_\(barConfig.position)"
                let thickness = CGFloat(barConfig.thickness > 0 ? barConfig.thickness : (barConfig.isVertical ? 54 : 48))
                let triggerBand: CGFloat = (autoHideRevealed[key] ?? false) ? (thickness + 20) : 6.0
                let sf = screen.frame

                let inZone: Bool
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

                let currentlyRevealed = autoHideRevealed[key] ?? false
                if inZone && !currentlyRevealed {
                    scheduleAutoHideTransition(key: key, reveal: true, delayMs: barConfig.hoverOpenDelayMs)
                } else if !inZone && currentlyRevealed {
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
