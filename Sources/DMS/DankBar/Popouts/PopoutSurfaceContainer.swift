import AppKit
import SwiftUI
import DMSCore

// MARK: - Popout Layout Helper (SURF-001 Connected Mode Positioning)

/// Calculates pixel-perfect positioning and bounding frames for shell popouts
/// according to DMS specification `SURF-001`.
/// In connected mode ("Gothic Corners"), the popout attaches flush to DankBar (`gap = 0`)
/// and expands its dimensions to accommodate concave fillet flanges that bridge into the bar.
@MainActor
public struct PopoutLayoutHelper {
    public static func frame(
        bodyWidth: CGFloat,
        bodyHeight: CGFloat,
        anchorX: CGFloat? = nil,
        screen: NSScreen,
        isControlCenter: Bool = false,
        anchorToControlCenter: Bool = false
    ) -> NSRect {
        let config = ConfigStore.shared.config
        let isConnected = config.gothCornersEnabled && !anchorToControlCenter
        let barPosition = config.barPosition.lowercased()
        let isBottom = barPosition == "bottom"
        let isVertical = barPosition == "left" || barPosition == "right"
        let filletR: CGFloat = isConnected ? CGFloat(config.barConfigs.first?.gothFilletRadius ?? 14.0) : 0.0

        let totalWidth: CGFloat = (isConnected && !isVertical) ? (bodyWidth + 2 * filletR) : bodyWidth
        let totalHeight: CGFloat = (isConnected && isVertical) ? (bodyHeight + 2 * filletR) : bodyHeight
        let gap: CGFloat = isConnected ? 0.0 : 8.0

        let visibleFrame = screen.visibleFrame
        let fullFrame = screen.frame
        let mouseLoc = NSEvent.mouseLocation

        let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == screen }) ?? DankBarController.shared.panel
        let barFrame = barPanel.frame

        var xPos: CGFloat
        var yPos: CGFloat

        if anchorToControlCenter {
            let ccPanel = ControlCenterController.shared.panel
            let ccFrame = ccPanel.frame
            xPos = ccFrame.width > 0 ? ccFrame.minX : (fullFrame.maxX - totalWidth - 12)
            if isBottom {
                yPos = min(visibleFrame.maxY - totalHeight - gap, ccFrame.maxY + gap)
            } else if !isVertical {
                yPos = ccFrame.height > 0 ? (ccFrame.maxY - totalHeight) : max(visibleFrame.minY + gap, ccFrame.minY)
            } else {
                yPos = max(visibleFrame.minY + 12, min(visibleFrame.maxY - totalHeight - 12, ccFrame.midY - totalHeight / 2.0))
            }
            return NSRect(x: xPos, y: yPos, width: totalWidth, height: totalHeight)
        }

        if isControlCenter {
            let marginX: CGFloat = CGFloat(config.barMarginX)
            xPos = fullFrame.maxX - totalWidth - marginX
            xPos = max(visibleFrame.minX + 8, min(visibleFrame.maxX - totalWidth - 8, xPos))

            if isBottom {
                let barTop = barFrame.height > 0 ? barFrame.maxY : (fullFrame.minY + 8 + DankBarController.barHeight)
                yPos = isConnected ? barTop : min(visibleFrame.maxY - totalHeight - gap, barTop + gap)
            } else if !isVertical {
                let barBottom = barFrame.height > 0 ? barFrame.minY : (fullFrame.maxY - 8 - DankBarController.barHeight)
                yPos = isConnected ? (barBottom - totalHeight) : max(visibleFrame.minY + gap, barBottom - totalHeight - gap)
            } else {
                let targetY = mouseLoc.y
                yPos = max(visibleFrame.minY + 12, min(visibleFrame.maxY - totalHeight - 12, targetY - totalHeight / 2.0))
                if barPosition == "left" {
                    let barRight = barFrame.width > 0 ? barFrame.maxX : (fullFrame.minX + DankBarController.verticalBarWidth + 8)
                    xPos = barRight + gap
                } else {
                    let barLeft = barFrame.width > 0 ? barFrame.minX : (fullFrame.maxX - DankBarController.verticalBarWidth - 8)
                    xPos = barLeft - totalWidth - gap
                }
            }
            return NSRect(x: xPos, y: yPos, width: totalWidth, height: totalHeight)
        }

        if isVertical {
            let targetY = mouseLoc.y
            yPos = targetY - totalHeight / 2.0 - (isConnected ? filletR : 0.0)
            yPos = max(visibleFrame.minY + 12, min(visibleFrame.maxY - totalHeight - 12, yPos))
            let barRight = barFrame.width > 0 ? barFrame.maxX : (fullFrame.minX + DankBarController.verticalBarWidth + 8)
            let barLeft = barFrame.width > 0 ? barFrame.minX : (fullFrame.maxX - DankBarController.verticalBarWidth - 8)
            if barPosition == "left" {
                xPos = barRight + gap
            } else {
                xPos = barLeft - totalWidth - gap
            }
        } else if isBottom {
            let targetX = (anchorX != nil && anchorX! > 0) ? anchorX! : mouseLoc.x
            var computedX = targetX - bodyWidth / 2.0 - (isConnected ? filletR : 0.0)
            computedX = max(visibleFrame.minX + 8, min(visibleFrame.maxX - totalWidth - 8, computedX))
            xPos = computedX

            let barTop = barFrame.height > 0 ? barFrame.maxY : (fullFrame.minY + 8 + DankBarController.barHeight)
            yPos = isConnected ? barTop : min(visibleFrame.maxY - totalHeight - gap, barTop + gap)
        } else {
            // Top bar
            let targetX = (anchorX != nil && anchorX! > 0) ? anchorX! : mouseLoc.x
            var computedX = targetX - bodyWidth / 2.0 - (isConnected ? filletR : 0.0)
            computedX = max(visibleFrame.minX + 8, min(visibleFrame.maxX - totalWidth - 8, computedX))
            xPos = computedX

            let barBottom = barFrame.height > 0 ? barFrame.minY : (fullFrame.maxY - 8 - DankBarController.barHeight)
            yPos = isConnected ? (barBottom - totalHeight) : max(visibleFrame.minY + gap, barBottom - totalHeight - gap)
        }

        return NSRect(x: xPos, y: yPos, width: totalWidth, height: totalHeight)
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

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.0, 0.8, 0.15)
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
/// In connected mode ("Gothic Corners"), renders continuous concave fillet arcs (`BarGothCornerShape`)
/// bridging the popout surface directly into the attached DankBar.
/// Complies with `SURF-002` protruding out of the bar into the screen with M3 `emphasizedDecel` animation.
public struct PopoutSurfaceContainer<Content: View>: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared

    public var bodyWidth: CGFloat
    public var bodyHeight: CGFloat
    public var cornerRadius: CGFloat
    public var anchorToControlCenter: Bool
    @ViewBuilder public let content: () -> Content

    @State private var isPresented: Bool = false

    public init(
        bodyWidth: CGFloat,
        bodyHeight: CGFloat,
        cornerRadius: CGFloat = 18,
        anchorToControlCenter: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.bodyWidth = bodyWidth
        self.bodyHeight = bodyHeight
        self.cornerRadius = cornerRadius
        self.anchorToControlCenter = anchorToControlCenter
        self.content = content
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
        let r = configStore.config.barConfigs.first?.gothFilletRadius ?? 14.0
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
                width: isVertical ? (isPresented ? totalWidth : 0) : totalWidth,
                height: !isVertical ? (isPresented ? totalHeight : 0) : totalHeight,
                alignment: protrusionAlignment
            )
            .clipped()
            .scaleEffect(
                x: isVertical ? (isPresented ? 1.0 : 0.05) : (isPresented ? 1.0 : 0.94),
                y: !isVertical ? (isPresented ? 1.0 : 0.05) : (isPresented ? 1.0 : 0.94),
                anchor: scaleAnchor
            )
            .opacity(isPresented ? 1.0 : 0.0)
        }
        .frame(width: totalWidth, height: totalHeight, alignment: protrusionAlignment)
        .onAppear {
            let curve = M3BezierCurve.emphasizedDecel
            withAnimation(.timingCurve(curve.c1x, curve.c1y, curve.c2x, curve.c2y, duration: 0.250)) {
                isPresented = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoutWillDismiss)) { _ in
            let curve = M3BezierCurve.emphasizedAccel
            withAnimation(.timingCurve(curve.c1x, curve.c1y, curve.c2x, curve.c2y, duration: 0.180)) {
                isPresented = false
            }
        }
    }
}
