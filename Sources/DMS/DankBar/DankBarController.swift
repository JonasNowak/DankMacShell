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
        reposition()
        setupScreenChangeObserver()
        setupConfigObserver()
    }

    public func show() {
        isVisible = true
        for panel in panels.values {
            panel.orderFront(nil)
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

                if barConfig.autoHide || barConfig.smartAutoHide {
                    anyAutoHide = true
                }

                let notch = screen.extractNotchGeometry(barConfig: barConfig)
                screenNotchGeometries[screenIndex] = notch

                let baseThickness = CGFloat(barConfig.thickness > 0 ? barConfig.thickness : (barConfig.isVertical ? 54 : 48))
                let isTopNotched = (barConfig.position.lowercased() == "top" && notch.hasNotch && barConfig.adaptToNotch)
                let thickness = isTopNotched ? max(baseThickness, CGFloat(notch.notchHeight) + 4) : baseThickness
                let margin = isTopNotched ? max(4.0, CGFloat(barConfig.margin) * 0.5) : CGFloat(barConfig.margin)
                let screenFrame = screen.frame

                let isRevealed = !(barConfig.autoHide || barConfig.smartAutoHide) || (autoHideRevealed[key] ?? false)
                let peekAmount: CGFloat = 2.0

                let frame: NSRect
                switch barConfig.position.lowercased() {
                case "top":
                    let topMargin = isTopNotched ? 2.0 : margin
                    let normalY = screenFrame.maxY - thickness - topMargin
                    let hiddenY = screenFrame.maxY - peekAmount
                    frame = NSRect(
                        x: screenFrame.minX + margin,
                        y: isRevealed ? normalY : hiddenY,
                        width: max(100, screenFrame.width - (margin * 2)),
                        height: thickness
                    )
                case "left":
                    let normalX = screenFrame.minX + margin
                    let hiddenX = screenFrame.minX - thickness + peekAmount
                    frame = NSRect(
                        x: isRevealed ? normalX : hiddenX,
                        y: screenFrame.minY + margin,
                        width: thickness,
                        height: max(100, screenFrame.height - (margin * 2))
                    )
                case "right":
                    let normalX = screenFrame.maxX - thickness - margin
                    let hiddenX = screenFrame.maxX - peekAmount
                    frame = NSRect(
                        x: isRevealed ? normalX : hiddenX,
                        y: screenFrame.minY + margin,
                        width: thickness,
                        height: max(100, screenFrame.height - (margin * 2))
                    )
                case "bottom":
                    fallthrough
                default:
                    let normalY = screenFrame.minY + margin
                    let hiddenY = screenFrame.minY - thickness + peekAmount
                    frame = NSRect(
                        x: screenFrame.minX + margin,
                        y: isRevealed ? normalY : hiddenY,
                        width: max(100, screenFrame.width - (margin * 2)),
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

                panel.alphaValue = isRevealed ? 1.0 : 0.02
                panel.setFrame(frame, display: true)
                if isVisible {
                    panel.orderFront(nil)
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

            for barConfig in activeConfigs where (barConfig.autoHide || barConfig.smartAutoHide) {
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
                self?.reposition()
            }
        }
    }

    private func setupConfigObserver() {
        ConfigStore.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reposition()
            }
            .store(in: &cancellables)
    }
}
