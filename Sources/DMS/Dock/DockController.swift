import AppKit
import SwiftUI
import Combine
import DMSCore

/// Multi-instance Desktop Dock layout engine and panel manager.
/// Resolves and displays Dock instances across monitors (NSScreen) and edges
/// per docs/spec/21-dock.md and upstream DockConfig.js.
@MainActor
public final class DockController {
    public static let shared = DockController()

    public private(set) var panels: [String: ShellPanel] = [:]
    public private(set) var triggerPanels: [String: ShellPanel] = [:]
    public private(set) var isVisible = true

    private var autoHiddenDocks: Set<String> = []
    private var configCancellable: AnyCancellable?

    private init() {
        reposition()
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reposition()
            }
        }

        configCancellable = ConfigStore.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reposition()
            }
    }

    public func show() {
        isVisible = true
        let configs = ConfigStore.shared.config.dockConfigs
        let hasSmartAutoHide = configs.contains { $0.smartAutoHide }
        for (key, panel) in panels {
            let screenIndex = Int(key.split(separator: "_").first ?? "") ?? 0
            if hasSmartAutoHide && DankBarController.shared.isScreenFullscreen(index: screenIndex) {
                continue
            }
            panel.orderFront(nil)
        }
    }

    public func hide() {
        isVisible = false
        for panel in panels.values {
            panel.orderOut(nil)
        }
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func updateDocks() {
        reposition()
    }

    public func reposition() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let screenNames = screens.map { $0.localizedName }
        let configs = ConfigStore.shared.config.dockConfigs
        var activeKeys = Set<String>()

        let barConfigs = ConfigStore.shared.config.barConfigs

        for (screenIndex, screen) in screens.enumerated() {
            let screenName = screen.localizedName
            let activeDocks = DockConfig.resolveAll(
                configs: configs,
                screenName: screenName,
                screenModel: nil,
                allScreens: screenNames
            )
            let matchingBars = barConfigs.filter { bar in
                bar.screenPreferences.contains("all") ||
                bar.screenPreferences.contains(screenName) ||
                (bar.screenPreferences.isEmpty && screenIndex == 0)
            }
            let activeBars = matchingBars.isEmpty ? [barConfigs.first ?? .default] : matchingBars

            for dockConfig in activeDocks {
                guard dockConfig.enabled else { continue }
                let key = "\(screenIndex)_\(dockConfig.id)_\(dockConfig.position)"
                activeKeys.insert(key)

                // Check if an active DankBar shares this same edge on this monitor
                var barClearance: CGFloat = 0
                for bar in activeBars {
                    let barPos = bar.position.lowercased()
                    let sharesEdge = (dockConfig.position == 0 && barPos == "top") ||
                                     (dockConfig.position == 1 && barPos == "bottom") ||
                                     (dockConfig.position == 2 && barPos == "left") ||
                                     (dockConfig.position == 3 && barPos == "right")
                    if sharesEdge {
                        barClearance = CGFloat(bar.thickness + bar.margin * 2)
                        break
                    }
                }

                let thickness = CGFloat(DockMagnificationEngine.effectiveThickness(
                    iconSize: Double(dockConfig.iconSize),
                    spacing: Double(dockConfig.spacing)
                ))
                let margin = CGFloat(dockConfig.margin)
                let bottomGap = CGFloat(dockConfig.bottomGap)
                let screenFrame = screen.frame

                let frame: NSRect
                switch dockConfig.position {
                case 0: // Top
                    if dockConfig.mode == "taskbar" {
                        frame = NSRect(
                            x: screenFrame.minX + margin,
                            y: screenFrame.maxY - barClearance - thickness - margin - bottomGap,
                            width: max(100, screenFrame.width - (margin * 2)),
                            height: thickness
                        )
                    } else {
                        // Compact: centered
                        let compactWidth = min(screenFrame.width - (margin * 2), CGFloat(max(300, dockConfig.iconSize * 8)))
                        frame = NSRect(
                            x: screenFrame.midX - (compactWidth / 2.0),
                            y: screenFrame.maxY - barClearance - thickness - margin - bottomGap,
                            width: compactWidth,
                            height: thickness
                        )
                    }
                case 2: // Left
                    if dockConfig.mode == "taskbar" {
                        frame = NSRect(
                            x: screenFrame.minX + barClearance + margin + bottomGap,
                            y: screenFrame.minY + margin,
                            width: thickness,
                            height: max(100, screenFrame.height - (margin * 2))
                        )
                    } else {
                        let compactHeight = min(screenFrame.height - (margin * 2), CGFloat(max(300, dockConfig.iconSize * 8)))
                        frame = NSRect(
                            x: screenFrame.minX + barClearance + margin + bottomGap,
                            y: screenFrame.midY - (compactHeight / 2.0),
                            width: thickness,
                            height: compactHeight
                        )
                    }
                case 3: // Right
                    if dockConfig.mode == "taskbar" {
                        frame = NSRect(
                            x: screenFrame.maxX - barClearance - thickness - margin - bottomGap,
                            y: screenFrame.minY + margin,
                            width: thickness,
                            height: max(100, screenFrame.height - (margin * 2))
                        )
                    } else {
                        let compactHeight = min(screenFrame.height - (margin * 2), CGFloat(max(300, dockConfig.iconSize * 8)))
                        frame = NSRect(
                            x: screenFrame.maxX - barClearance - thickness - margin - bottomGap,
                            y: screenFrame.midY - (compactHeight / 2.0),
                            width: thickness,
                            height: compactHeight
                        )
                    }
                case 1: // Bottom
                    fallthrough
                default:
                    if dockConfig.mode == "taskbar" {
                        frame = NSRect(
                            x: screenFrame.minX + margin,
                            y: screenFrame.minY + barClearance + margin + bottomGap,
                            width: max(100, screenFrame.width - (margin * 2)),
                            height: thickness
                        )
                    } else {
                        let compactWidth = min(screenFrame.width - (margin * 2), CGFloat(max(300, dockConfig.iconSize * 8)))
                        frame = NSRect(
                            x: screenFrame.midX - (compactWidth / 2.0),
                            y: screenFrame.minY + barClearance + margin + bottomGap,
                            width: compactWidth,
                            height: thickness
                        )
                    }
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
                    panel.level = dockConfig.useOverlayLayer ? .screenSaver : .floating
                    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                    panels[key] = panel
                }

                let isScreenFS = DankBarController.shared.isScreenFullscreen(index: screenIndex)
                if dockConfig.smartAutoHide && isScreenFS {
                    panel.orderOut(nil)
                    continue
                }

                panel.setFrame(frame, display: true)
                panel.contentView = NSHostingView(rootView: DockView(config: dockConfig))

                if isVisible {
                    panel.orderFront(nil)
                }
            }
        }

        // Clean up panels that are no longer active
        for (key, panel) in panels where !activeKeys.contains(key) {
            panel.orderOut(nil)
            panels.removeValue(forKey: key)
        }
    }
}
