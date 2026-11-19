import AppKit
import SwiftUI
import DMSCore
import MaterialMacLibrary

// MARK: - Popout Layout Helper (SURF-001 Connected Mode Positioning)

/// Calculates pixel-perfect positioning and bounding frames for shell popouts
/// according to DMS specification `SURF-001`.
/// In connected mode ("Gothic Corners"), the popout attaches flush to DankBar (`gap = 0`)
/// and expands its dimensions to accommodate concave fillet flanges that bridge into the bar.
/// Pure positioning math is delegated to `MaterialComponents.PopoutLayoutHelper`.
@MainActor
public struct PopoutLayoutHelper {
    /// Resolves the active `BarConfig` for a specific screen: explicit per-screen
    /// `screenPreferences` win over `"all"` configs, which win over the first config.
    public static func activeBarConfig(for screen: NSScreen) -> BarConfig {
        let configs = ConfigStore.shared.config.barConfigs
        let name = screen.localizedName
        if let explicit = configs.first(where: {
            !$0.screenPreferences.isEmpty
                && !$0.screenPreferences.contains("all")
                && $0.screenPreferences.contains(name)
        }) {
            return explicit
        }
        return configs.first(where: { $0.screenPreferences.contains("all") || $0.screenPreferences.contains(name) })
            ?? configs.first
            ?? .default
    }

    public static func frame(
        bodyWidth: CGFloat,
        bodyHeight: CGFloat,
        anchorX: CGFloat? = nil,
        screen: NSScreen,
        isControlCenter: Bool = false,
        anchorToControlCenter: Bool = false
    ) -> NSRect {
        let config = ConfigStore.shared.config
        let barConfig = activeBarConfig(for: screen)
        let isConnected = config.gothCornersEnabled && !anchorToControlCenter
        let barPosition = barConfig.position.lowercased()
        let filletR: CGFloat = isConnected ? CGFloat(barConfig.gothFilletRadius) : 0.0

        let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == screen }) ?? DankBarController.shared.panel

        let input = PopoutLayoutInput(
            bodyWidth: bodyWidth,
            bodyHeight: bodyHeight,
            anchorX: anchorX,
            barPosition: barPosition,
            connected: isConnected,
            filletRadius: filletR,
            barFrame: barPanel.frame,
            visibleFrame: screen.visibleFrame,
            fullFrame: screen.frame,
            mouseLocation: NSEvent.mouseLocation,
            marginX: CGFloat(config.barMarginX),
            isControlCenter: isControlCenter,
            anchorToControlCenter: anchorToControlCenter,
            controlCenterFrame: ControlCenterController.shared.panel.frame,
            barHeight: DankBarController.barHeight,
            verticalBarWidth: DankBarController.verticalBarWidth
        )
        var f = MaterialComponents.PopoutLayoutHelper.frame(for: input)

        // The library falls back to the mouse location when `anchorX <= 0`, which breaks
        // popouts anchored on monitors left of the primary display (negative X). Recompute
        // the horizontal position from the raw anchor whenever one is provided.
        if let anchorX = anchorX, !anchorToControlCenter, !isControlCenter,
           barPosition != "left", barPosition != "right" {
            var computedX = anchorX - bodyWidth / 2.0 - (isConnected ? filletR : 0.0)
            computedX = max(screen.visibleFrame.minX + 8, min(screen.visibleFrame.maxX - f.width - 8, computedX))
            f.origin.x = computedX
        }

        // Clamp the popout inside the screen's visible frame even in connected mode, so
        // edge-anchored or oversized popouts never render off-screen.
        f.origin.x = max(screen.visibleFrame.minX + 8, min(screen.visibleFrame.maxX - f.width - 8, f.origin.x))
        if f.height <= screen.visibleFrame.height - 16 {
            f.origin.y = max(screen.visibleFrame.minY + 8, min(screen.visibleFrame.maxY - f.height - 8, f.origin.y))
        }
        return NSRect(x: f.minX, y: f.minY, width: f.width, height: f.height)
    }
}

// MARK: - Popout Animation Helper (SURF-002 Motion Architecture)

extension Notification.Name {
    public static let popoutWillDismiss = Notification.Name("DMSPopoutWillDismiss")
}

/// Coordinates physical popout motion choreography according to DMS specification `SURF-002`:
/// Popouts are anchored flush against DankBar and physically PROTRUDE into the screen from the bar edge:
/// - Entrance: Grows outward from the bar seam, expanding in height/width from 0 to full dimensions,
///   scale 0.94 to 1.0, and opacity 0.0 to 1.0 over 250ms with M3 `emphasizedDecel` [0.05, 0.7, 0.1, 1.0].
/// - Exit: Retracts back into the bar edge over 180ms with M3 `emphasizedAccel` [0.3, 0.0, 0.8, 0.15].
/// Durations and curves are delegated to `MaterialComponents.PopoutAnimationHelper`.
@MainActor
public enum PopoutAnimationHelper {
    public static func animateIn(
        panel: NSPanel,
        targetFrame: NSRect,
        screen: NSScreen,
        anchorToControlCenter: Bool = false,
        completion: (@MainActor @Sendable () -> Void)? = nil
    ) {
        // Window frame is anchored flush against DankBar (rock-solid anchor, zero window translation)
        panel.setFrame(targetFrame, display: true)
        panel.alphaValue = 1.0

        // In connected mode, order beneath DankBar so the protrusion grows organically out of the bar
        if !anchorToControlCenter {
            let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == screen }) ?? DankBarController.shared.panel
            if barPanel.windowNumber > 0 {
                panel.order(.below, relativeTo: barPanel.windowNumber)
            } else {
                panel.orderFront(nil)
            }
        } else {
            panel.orderFront(nil)
        }

        completion?()
    }

    public static func animateOut(
        panel: NSPanel?,
        screen: NSScreen?,
        anchorToControlCenter: Bool = false,
        completion: (@MainActor @Sendable () -> Void)? = nil
    ) {
        guard let panel = panel, panel.isVisible else {
            panel?.orderOut(nil)
            completion?()
            return
        }

        // Notify view hierarchy to retract protrusion back into the bar
        NotificationCenter.default.post(name: .popoutWillDismiss, object: panel)

        let exitCurve = MaterialComponents.PopoutAnimationHelper.exitCurve
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = MaterialComponents.PopoutAnimationHelper.exitDuration
            ctx.timingFunction = CAMediaTimingFunction(
                controlPoints: Float(exitCurve.c1x), Float(exitCurve.c1y), Float(exitCurve.c2x), Float(exitCurve.c2y)
            )
            panel.animator().alphaValue = 0.0
        } completionHandler: {
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                panel.alphaValue = 1.0
                completion?()
            }
        }
    }
}

// MARK: - Popout Surface Container (SURF-001 / SURF-002 Connected Gothic Chrome)

/// Reusable container view for all DankBar popouts and overlay panels.
/// In connected mode ("Gothic Corners"), renders continuous concave fillet arcs (delegated to
/// `MaterialShapes.GothEarCornerShape` via `BarGothCornerShape`) bridging the popout surface
/// directly into the attached DankBar, over a `MaterialComponents.GlassSurfaceBackground`.
/// Complies with `SURF-002` protruding out of the bar into the screen; protrusion motion math
/// (scale/opacity/collapsed size/curves) is delegated to `MaterialComponents.PopoutAnimationHelper`.
public struct PopoutSurfaceContainer<Content: View>: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared

    public var bodyWidth: CGFloat
    public var bodyHeight: CGFloat
    public var cornerRadius: CGFloat
    public var anchorToControlCenter: Bool
    /// Owning panel of this popout. When set, `.popoutWillDismiss` notifications are only
    /// honored when `notification.object` is exactly this panel, so dismissing one popout
    /// never collapses another open popout (or Control Center) to 0x0.
    public var ownerPanel: NSPanel?
    @ViewBuilder public let content: () -> Content

    @State private var isPresented: Bool = false
    /// Panel hosting this view, auto-resolved from the view hierarchy when `ownerPanel`
    /// was not passed explicitly (covers Control Center / Dash / Process List surfaces).
    @State private var resolvedPanel: NSPanel?

    public init(
        bodyWidth: CGFloat,
        bodyHeight: CGFloat,
        cornerRadius: CGFloat = 18,
        anchorToControlCenter: Bool = false,
        ownerPanel: NSPanel? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.bodyWidth = bodyWidth
        self.bodyHeight = bodyHeight
        self.cornerRadius = cornerRadius
        self.anchorToControlCenter = anchorToControlCenter
        self.ownerPanel = ownerPanel
        self.content = content
    }

    private var effectiveOwnerPanel: NSPanel? {
        ownerPanel ?? resolvedPanel
    }

    private var isConnected: Bool {
        configStore.config.gothCornersEnabled && !anchorToControlCenter
    }

    private var barPosition: String {
        configStore.config.barPosition.lowercased()
    }

    private var isVertical: Bool {
        barPosition == "left" || barPosition == "right"
    }

    private var filletRadius: CGFloat {
        guard isConnected else { return 0.0 }
        let screen = effectiveOwnerPanel?.screen ?? NSScreen.main ?? NSScreen.screens.first
        let r = screen.map { PopoutLayoutHelper.activeBarConfig(for: $0).gothFilletRadius } ?? (configStore.config.barConfigs.first?.gothFilletRadius ?? 14.0)
        return max(4.0, CGFloat(r))
    }

    private var totalWidth: CGFloat {
        (isConnected && !isVertical) ? (bodyWidth + 2 * filletRadius) : bodyWidth
    }

    private var totalHeight: CGFloat {
        (isConnected && isVertical) ? (bodyHeight + 2 * filletRadius) : bodyHeight
    }

    private var scaleAnchor: UnitPoint {
        switch barPosition {
        case "top":
            return .top
        case "left":
            return .leading
        case "right":
            return .trailing
        case "bottom":
            fallthrough
        default:
            return .bottom
        }
    }

    private var protrusionAlignment: Alignment {
        switch barPosition {
        case "top":
            return .top
        case "left":
            return .leading
        case "right":
            return .trailing
        case "bottom":
            fallthrough
        default:
            return .bottom
        }
    }

    public var body: some View {
        let isConnected = self.isConnected
        let isVertical = self.isVertical
        let scale = MaterialComponents.PopoutAnimationHelper.scale(isVerticalBar: isVertical, presented: isPresented)
        let collapsed = MaterialComponents.PopoutAnimationHelper.collapsedSize(
            isVerticalBar: isVertical,
            total: CGSize(width: totalWidth, height: totalHeight),
            presented: isPresented
        )

        ZStack(alignment: protrusionAlignment) {
            ZStack(alignment: protrusionAlignment) {
                ZStack {
                    content()
                        .frame(width: bodyWidth, height: bodyHeight)
                        .padding(.horizontal, (isConnected && !isVertical) ? filletRadius : 0)
                        .padding(.vertical, (isConnected && isVertical) ? filletRadius : 0)
                }
                .frame(width: totalWidth, height: totalHeight)
                .background(GlassSurfaceBackground())
                .clipShape(
                    BarGothCornerShape(
                        position: barPosition,
                        cornerStyle: isConnected ? .gothic : .rounded,
                        cornerRadius: cornerRadius,
                        filletRadius: filletRadius,
                        isVertical: isVertical,
                        closedSeam: true
                    )
                )
                .overlay(
                    BarGothCornerShape(
                        position: barPosition,
                        cornerStyle: isConnected ? .gothic : .rounded,
                        cornerRadius: cornerRadius,
                        filletRadius: filletRadius,
                        isVertical: isVertical,
                        closedSeam: isConnected ? false : true
                    )
                    .stroke(theme.panelBorderColor, lineWidth: 1)
                )
                .shadow(
                    color: theme.adaptiveShadowColor(baseOpacity: isConnected ? 0.25 : 0.35),
                    radius: 18,
                    x: 0,
                    y: barPosition == "bottom" ? -4 : 8
                )
            }
            .frame(
                width: isVertical ? collapsed.width : totalWidth,
                height: !isVertical ? collapsed.height : totalHeight,
                alignment: protrusionAlignment
            )
            .clipped()
            .scaleEffect(x: scale.width, y: scale.height, anchor: scaleAnchor)
            .opacity(MaterialComponents.PopoutAnimationHelper.opacity(presented: isPresented))
        }
        .frame(width: totalWidth, height: totalHeight, alignment: protrusionAlignment)
        .materialTheme(theme.materialTheme)
        .background(
            PanelReader { panel in
                if resolvedPanel == nil {
                    resolvedPanel = panel
                }
            }
            .frame(width: 0, height: 0)
        )
        .onAppear {
            if theme.motionTokens.reducedMotion {
                isPresented = true
            } else {
                withAnimation(MaterialComponents.PopoutAnimationHelper.entranceAnimation()) {
                    isPresented = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoutWillDismiss)) { notification in
            // Only react to dismissal of OUR OWN panel: dismissing one popout must never
            // collapse Control Center or another open popout to 0x0.
            guard let sender = notification.object as? NSPanel else { return }
            if let owner = effectiveOwnerPanel {
                guard sender === owner else { return }
            }
            if theme.motionTokens.reducedMotion {
                isPresented = false
            } else {
                withAnimation(MaterialComponents.PopoutAnimationHelper.exitAnimation()) {
                    isPresented = false
                }
            }
        }
    }
}

/// Zero-size `NSViewRepresentable` that reports the `NSPanel` hosting the view hierarchy,
/// used to auto-resolve `ownerPanel` when a surface does not pass it explicitly.
private struct PanelReader: NSViewRepresentable {
    let onPanel: (NSPanel?) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onPanel = onPanel
        return view
    }

    func updateNSView(_ nsView: ReaderView, context: Context) {
        nsView.onPanel = onPanel
    }

    final class ReaderView: NSView {
        var onPanel: ((NSPanel?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onPanel?(window as? NSPanel)
        }
    }
}
