import AppKit
import SwiftUI
import Combine
import DMSCore

// MARK: - NSScreen Notch Geometry Extraction

public extension NSScreen {
    /// Extracts physical Mac hardware notch dimensions (or simulated notch dimensions) for this display.
    @MainActor
    func extractNotchGeometry(barConfig: BarConfig? = nil) -> ScreenNotchGeometry {
        let topInset = Double(safeAreaInsets.top)
        let leftAuxWidth: Double?
        let rightAuxMinX: Double?
        let rightAuxWidth: Double?

        if let leftRect = auxiliaryTopLeftArea, let rightRect = auxiliaryTopRightArea,
           leftRect.width > 0, rightRect.width > 0 {
            leftAuxWidth = Double(leftRect.width)
            rightAuxMinX = Double(rightRect.minX - frame.minX)
            rightAuxWidth = Double(rightRect.width)
        } else {
            leftAuxWidth = nil
            rightAuxMinX = nil
            rightAuxWidth = nil
        }

        let cfg = barConfig ?? ConfigStore.shared.config.barConfigs.first ?? .default
        return ScreenNotchGeometry.fromScreenMeasurements(
            screenID: localizedName,
            screenWidth: Double(frame.width),
            screenHeight: Double(frame.height),
            safeAreaTop: topInset,
            auxiliaryLeftWidth: leftAuxWidth,
            auxiliaryRightMinX: rightAuxMinX,
            auxiliaryRightWidth: rightAuxWidth,
            simulateNotch: cfg.simulateNotch,
            simulatedNotchWidth: cfg.simulatedNotchWidth,
            simulatedNotchHeight: cfg.simulatedNotchHeight
        )
    }
}

// MARK: - Dynamic Island Window & State Controller

/// Manages the Dynamic Island (`DIsland`) lifecycle, 8-DOF spring physics animation loop,
/// multi-monitor notch docking, and priority state machine per `docs/spec/24-island-surface-widgets.md`.
@MainActor
public final class DIslandController: ObservableObject {
    public static let shared = DIslandController()

    @Published public private(set) var presentationState: IslandPresentationState = .idle
    @Published public private(set) var currentGeometry: IslandGeometryVector
    @Published public private(set) var isHovered: Bool = false
    @Published public private(set) var currentNotch: ScreenNotchGeometry = .standardMonitor()

    public var activeActivity: IslandActivity {
        presentationState.activity
    }

    @Published public var osdPayload: (icon: String, label: String, progress: Double?)? = nil
    @Published public var toastPayload: (title: String, body: String, level: String)? = nil

    public private(set) var panel: ShellPanel?
    private var hostingView: NSHostingView<DIslandView>?

    private var stateMachine = IslandStateMachine()
    private var springEngine: VectorSpringEngine
    private var animationTimer: Timer?
    private var hoverOpenTask: Task<Void, Never>?
    private var hoverCloseTask: Task<Void, Never>?
    private var autoDismissTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let initialSettings = ConfigStore.shared.config.islandSettings
        let screen = NSScreen.main ?? NSScreen.screens.first
        let notch = screen?.extractNotchGeometry() ?? .standardMonitor()
        self.currentNotch = notch

        let initialGeom = IslandStateMachine.targetGeometry(
            for: .idle,
            settings: initialSettings,
            notch: notch
        )
        self.currentGeometry = initialGeom
        self.springEngine = VectorSpringEngine(
            initial: initialGeom,
            stiffness: initialSettings.springStiffness,
            damping: initialSettings.springDamping
        )

        setupObservers()
        reposition()
    }

    // MARK: - Public Controls & IPC Actions

    public var settings: IslandSettings {
        ConfigStore.shared.config.islandSettings
    }

    public func refreshSettings() {
        reposition()
    }

    /// Returns the horizontal exclusion width that the Dynamic Island occupies in the top bar center area.
    public func exclusionWidth(for screen: NSScreen, barPosition: String) -> CGFloat {
        guard barPosition.lowercased() == "top" else { return 0 }
        let s = settings
        guard s.instance != .off else { return 0 }
        if s.float && s.edge.lowercased() != "top" {
            return 0
        }
        return CGFloat(max(currentGeometry.width, s.compactWidth))
    }

    public func expand(activity: IslandActivity? = nil) {
        let s = settings
        let target = activity ?? defaultExpandActivity(for: s)
        open(activity: target)
    }

    public func collapse() {
        close()
    }

    public func toggleExpanded(activity: IslandActivity? = nil) {
        toggle(activity: activity)
    }

    public func toggle(activity: IslandActivity? = nil) {
        let s = settings
        if presentationState.isExpanded {
            let currentAct = presentationState.activity
            if let requested = activity, requested != currentAct {
                open(activity: requested)
            } else {
                close()
            }
        } else {
            let target = activity ?? defaultExpandActivity(for: s)
            open(activity: target)
        }
    }

    public func open(activity: IslandActivity) {
        let s = settings
        guard s.enabledActivities.contains(activity.rawValue) || activity == .home || activity == .osd || activity == .notification else {
            return
        }
        autoDismissTask?.cancel()
        stateMachine.expand(to: activity)
        syncStateAndAnimate()
    }

    public func close() {
        autoDismissTask?.cancel()
        stateMachine.collapse()
        syncStateAndAnimate()
    }

    public func triggerOSD(icon: String, label: String, progress: Double? = nil) {
        let s = settings
        guard s.instance != .off, s.enabledActivities.contains(IslandActivity.osd.rawValue) else { return }
        osdPayload = (icon: icon, label: label, progress: progress)
        stateMachine.triggerOSD(at: Date())
        syncStateAndAnimate()
        scheduleAutoDismiss(afterSeconds: 3.05)
    }

    public func triggerNotification(title: String, body: String, level: String = "info") {
        let s = settings
        guard s.instance != .off, s.enabledActivities.contains(IslandActivity.notification.rawValue) else { return }
        toastPayload = (title: title, body: body, level: level)
        stateMachine.triggerNotification(at: Date())
        syncStateAndAnimate()
        scheduleAutoDismiss(afterSeconds: 5.05)
    }

    public func setHovered(_ hovering: Bool) {
        guard isHovered != hovering else { return }
        isHovered = hovering
        let s = settings
        guard s.hoverExpand else { return }

        hoverOpenTask?.cancel()
        hoverCloseTask?.cancel()

        if hovering {
            let delayNs = UInt64(max(0, s.hoverDelayMs)) * 1_000_000
            hoverOpenTask = Task { @MainActor [weak self] in
                if delayNs > 0 {
                    try? await Task.sleep(nanoseconds: delayNs)
                }
                guard !Task.isCancelled, let self = self, self.isHovered else { return }
                if !self.presentationState.isExpanded {
                    let act = self.defaultExpandActivity(for: self.settings)
                    self.open(activity: act)
                }
            }
        } else {
            let delayNs = UInt64(max(50, s.hoverCloseDelayMs)) * 1_000_000
            hoverCloseTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: delayNs)
                guard !Task.isCancelled, let self = self, !self.isHovered else { return }
                if self.presentationState.isExpanded {
                    self.close()
                }
            }
        }
    }

    public func move(edge: String? = nil, anchorX: Double? = nil, anchorY: Double? = nil) {
        ConfigStore.shared.update(immediate: false) { cfg in
            var s = cfg.islandSettings
            if let edge = edge { s.edge = edge }
            if let x = anchorX { s.anchorX = min(1.0, max(0.0, x)) }
            if let y = anchorY { s.anchorY = min(1.0, max(0.0, y)) }
            cfg.islandSettings = s
        }
        reposition()
    }

    public func centerOnEdge() {
        move(anchorX: 0.5, anchorY: 0.0)
    }

    // MARK: - Window & Geometry Management

    public func reposition() {
        let s = settings
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let notch = screen.extractNotchGeometry()
        currentNotch = notch

        guard s.instance != .off else {
            panel?.orderOut(nil)
            stopAnimationLoop()
            return
        }

        let enabledSet = Set(s.enabledActivities.compactMap { IslandActivity(rawValue: $0) })
        stateMachine.enabledModules = enabledSet.union([.home])

        let targetGeom = IslandStateMachine.targetGeometry(
            for: presentationState,
            settings: s,
            notch: notch
        )
        springEngine.stiffness = s.springStiffness
        springEngine.damping = s.springDamping
        springEngine.target = targetGeom

        if ThemeStore.shared.motionTokens.reducedMotion {
            springEngine.snapToTarget()
            currentGeometry = targetGeom
            updatePanelFrame(on: screen, geometry: targetGeom, settings: s, notch: notch)
        } else {
            startAnimationLoop()
        }
    }

    private func syncStateAndAnimate() {
        let nextState = stateMachine.resolveState(at: Date())
        if presentationState != nextState {
            presentationState = nextState
        }
        reposition()
        DankBarController.shared.reposition()
    }

    private func scheduleAutoDismiss(afterSeconds seconds: Double) {
        autoDismissTask?.cancel()
        autoDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, let self = self else { return }
            self.syncStateAndAnimate()
        }
    }

    private func defaultExpandActivity(for s: IslandSettings) -> IslandActivity {
        if NowPlayingService.shared.currentTrack.isPlaying && s.enabledActivities.contains(IslandActivity.media.rawValue) {
            return .media
        }
        if toastPayload != nil && s.enabledActivities.contains(IslandActivity.notification.rawValue) {
            return .notification
        }
        return .home
    }

    private func startAnimationLoop() {
        guard animationTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stepSpringPhysics()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.animationTimer = timer
    }

    private func stopAnimationLoop() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func stepSpringPhysics() {
        let geom = springEngine.step(dt: 1.0 / 60.0)
        currentGeometry = geom
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            updatePanelFrame(on: screen, geometry: geom, settings: settings, notch: currentNotch)
        }
        if springEngine.isAtRest {
            stopAnimationLoop()
        }
    }

    private func updatePanelFrame(
        on screen: NSScreen,
        geometry: IslandGeometryVector,
        settings: IslandSettings,
        notch: ScreenNotchGeometry
    ) {
        let screenFrame = screen.frame
        let isNotchAttached = !settings.float && (settings.instance == .notch || (settings.instance == .mainBar && notch.hasNotch))
        let isTopAnchored = isNotchAttached || settings.edge.lowercased() == "top"
        let gothFlange: CGFloat = (settings.gothCorners && isTopAnchored) ? 14.0 : 0.0
        let width = max(80.0, CGFloat(geometry.width) + gothFlange * 2)
        let height = max(24.0, CGFloat(geometry.height))

        let originX: CGFloat
        let originY: CGFloat

        if settings.instance == .off {
            panel?.orderOut(nil)
            return
        } else if settings.float {
            switch settings.edge.lowercased() {
            case "bottom":
                originX = screenFrame.minX + (screenFrame.width - width) * CGFloat(settings.anchorX) + CGFloat(geometry.offsetX)
                originY = screenFrame.minY + 8.0 + CGFloat(geometry.offsetY)
            case "left":
                originX = screenFrame.minX + 8.0 + CGFloat(geometry.offsetX)
                originY = screenFrame.minY + (screenFrame.height - height) * (1.0 - CGFloat(settings.anchorY))
            case "right":
                originX = screenFrame.maxX - width - 8.0 + CGFloat(geometry.offsetX)
                originY = screenFrame.minY + (screenFrame.height - height) * (1.0 - CGFloat(settings.anchorY))
            default:
                originX = screenFrame.minX + (screenFrame.width - width) * CGFloat(settings.anchorX) + CGFloat(geometry.offsetX)
                originY = screenFrame.maxY - height - 8.0 - CGFloat(geometry.offsetY)
            }
        } else if isNotchAttached {
            let centerX = screenFrame.minX + (notch.hasNotch ? CGFloat(notch.notchMidX) : screenFrame.width * 0.5)
            originX = centerX - width * 0.5 + CGFloat(geometry.offsetX)
            originY = screenFrame.maxY - height - CGFloat(geometry.offsetY)
        } else {
            let topBar = ConfigStore.shared.config.barConfigs.first(where: { $0.position.lowercased() == "top" })
            let barMargin = CGFloat(topBar?.margin ?? 8)
            originX = screenFrame.minX + (screenFrame.width - width) * 0.5 + CGFloat(geometry.offsetX)
            originY = screenFrame.maxY - height - barMargin - CGFloat(geometry.offsetY)
        }

        let frame = NSRect(x: originX, y: originY, width: width, height: height)

        let islandPanel: ShellPanel
        if let existing = panel {
            islandPanel = existing
        } else {
            islandPanel = ShellPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            islandPanel.level = .statusBar + 1
            islandPanel.hasShadow = false
            islandPanel.onEscape = { [weak self] in
                self?.close()
            }
            let host = NSHostingView(rootView: DIslandView(controller: self))
            islandPanel.contentView = host
            self.hostingView = host
            self.panel = islandPanel
        }

        if let host = hostingView {
            host.rootView = DIslandView(controller: self)
        }
        islandPanel.setFrame(frame, display: true)
        islandPanel.orderFront(nil)
    }

    private func setupObservers() {
        ConfigStore.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reposition()
            }
            .store(in: &cancellables)

        NowPlayingService.shared.$currentTrack
            .receive(on: RunLoop.main)
            .sink { [weak self] track in
                guard let self = self else { return }
                let enabled = self.settings.enabledActivities.contains(IslandActivity.media.rawValue)
                self.stateMachine.isMediaPlaying = track.isPlaying && enabled
                self.syncStateAndAnimate()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reposition()
            }
        }
    }
}
