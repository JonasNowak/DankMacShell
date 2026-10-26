import AppKit
import SwiftUI
import DMSCore

/// Dedicated Bar Popout for Battery diagnostics, power draw, health, and 24h discharge history.
/// Reuses `BatteryDetailPage` as requested.
@MainActor
public final class BatteryPopoutController: ObservableObject {
    public static let shared = BatteryPopoutController()

    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false
    private var globalClickMonitor: Any?

    private init() {}

    public func toggle(anchorX: CGFloat? = nil) {
        if isVisible {
            hide()
        } else {
            show(anchorX: anchorX)
        }
    }

    public func show(anchorX: CGFloat? = nil) {
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first else { return }

        // Close peer popouts
        DashController.shared.hide()
        AudioPopoutController.shared.hide()
        DurationPopoutController.shared.hide()
        ColorPickerPopoutController.shared.hide()
        PowerPopoutController.shared.hide()
        ProcessListController.shared.hide()
        ControlCenterController.shared.hide()

        let popoutWidth: CGFloat = 255
        let popoutHeight: CGFloat = 355
        let gap: CGFloat = 10
        let isBottom = ConfigStore.shared.config.barPosition.lowercased() == "bottom"
        let isVertical = ConfigStore.shared.config.barPosition.lowercased() == "left" || ConfigStore.shared.config.barPosition.lowercased() == "right"

        let visibleFrame = screen.visibleFrame
        let fullFrame = screen.frame

        let targetX = (anchorX != nil && anchorX! > 0) ? anchorX! : mouseLoc.x
        var xPos = targetX - popoutWidth / 2.0
        xPos = max(visibleFrame.minX + 12, min(visibleFrame.maxX - popoutWidth - 12, xPos))

        let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == screen }) ?? DankBarController.shared.panel
        let barFrame = barPanel.frame

        let yPos: CGFloat
        if isBottom {
            let barTop = barFrame.height > 0 ? barFrame.maxY : (fullFrame.minY + 8 + DankBarController.barHeight)
            yPos = min(visibleFrame.maxY - popoutHeight - gap, barTop + gap)
        } else if !isVertical {
            let barBottom = barFrame.height > 0 ? barFrame.minY : (fullFrame.maxY - 8 - DankBarController.barHeight)
            yPos = max(visibleFrame.minY + gap, barBottom - popoutHeight - gap)
        } else {
            let targetY = mouseLoc.y
            yPos = max(visibleFrame.minY + 12, min(visibleFrame.maxY - popoutHeight - 12, targetY - popoutHeight / 2.0))
            let barRight = barFrame.width > 0 ? barFrame.maxX : (fullFrame.minX + DankBarController.verticalBarWidth + 8)
            let barLeft = barFrame.width > 0 ? barFrame.minX : (fullFrame.maxX - DankBarController.verticalBarWidth - 8)
            if ConfigStore.shared.config.barPosition.lowercased() == "left" {
                xPos = barRight + gap
            } else {
                xPos = barLeft - popoutWidth - gap
            }
        }

        let rect = NSRect(x: xPos, y: yPos, width: popoutWidth, height: popoutHeight)

        let panel = ShellPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating

        let rootView = BatteryPopoutView { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: rootView)

        self.panel = panel
        self.isVisible = true

        panel.makeKeyAndOrderFront(nil)
        installClickMonitor()
    }

    public func hide() {
        guard isVisible else { return }
        removeClickMonitor()
        panel?.orderOut(nil)
        panel = nil
        isVisible = false
    }

    private func installClickMonitor() {
        removeClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hide()
            }
        }
    }

    private func removeClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}

/// Popout sheet view wrapping BatteryDetailPage with M3 styling.
public struct BatteryPopoutView: View {
    @ObservedObject private var theme = ThemeStore.shared
    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "bolt.batteryblock.fill")
                    .foregroundColor(theme.primary)
                Text("Battery & Power")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.onSurfaceVariant)
                        .frame(width: 22, height: 22)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.surfaceContainerHigh)

            Divider().background(theme.outlineVariant.opacity(0.4))

            ScrollView(.vertical, showsIndicators: false) {
                BatteryDetailPage()
                    .padding(10)
            }
        }
        .frame(width: 255, height: 355)
        .background(theme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.outlineVariant.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
    }
}
