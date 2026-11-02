import AppKit
import SwiftUI
import DMSCore

/// Dedicated Bar Popout for system power actions with hold-to-confirm safety progress.
/// Complies with `docs/spec/20-bar-widgets.md` `PowerMenuPopout.qml`.
/// Supports anchoring to DankBar power widget (220pt) or morphing to Control Center width when triggered from CC.
@MainActor
public final class PowerPopoutController: ObservableObject {
    public static let shared = PowerPopoutController()

    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false
    private var globalClickMonitor: Any?

    private init() {}

    public func toggle(anchorX: CGFloat? = nil, anchorToControlCenter: Bool = false) {
        if isVisible {
            hide()
        } else {
            show(anchorX: anchorX, anchorToControlCenter: anchorToControlCenter)
        }
    }

    public func show(anchorX: CGFloat? = nil, anchorToControlCenter: Bool = false) {
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first else { return }

        // Close peer popouts
        DashController.shared.hide()
        AudioPopoutController.shared.hide()
        BatteryPopoutController.shared.hide()
        DurationPopoutController.shared.hide()
        ColorPickerPopoutController.shared.hide()
        ProcessListController.shared.hide()
        if !anchorToControlCenter {
            ControlCenterController.shared.hide()
        }

        let bodyWidth: CGFloat = anchorToControlCenter ? (ControlCenterController.shared.panel.frame.width > 0 ? ControlCenterController.shared.panel.frame.width : 295) : 220
        let bodyHeight: CGFloat = 290

        let rect = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: bodyHeight,
            anchorX: anchorX,
            screen: screen,
            anchorToControlCenter: anchorToControlCenter
        )

        let panel = ShellPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu

        let rootView = PowerPopoutView(width: bodyWidth, anchorToControlCenter: anchorToControlCenter) { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: rootView)

        self.panel = panel
        self.isVisible = true

        PopoutAnimationHelper.animateIn(panel: panel, targetFrame: rect, screen: screen, anchorToControlCenter: anchorToControlCenter)
        installClickMonitor()
    }

    public func hide() {
        guard isVisible else { return }
        removeClickMonitor()
        isVisible = false

        let panelToClose = self.panel
        let screen = panelToClose?.screen ?? NSScreen.main
        self.panel = nil

        PopoutAnimationHelper.animateOut(panel: panelToClose, screen: screen)
    }

    private func installClickMonitor() {
        removeClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isVisible else { return }
                let clickLoc = NSEvent.mouseLocation
                if let p = self.panel, !NSMouseInRect(clickLoc, p.frame, false) {
                    self.hide()
                    let ccPanel = ControlCenterController.shared.panel
                    if !NSMouseInRect(clickLoc, ccPanel.frame, false) {
                        ControlCenterController.shared.hide()
                    }
                }
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

/// M3 Popout View for Lock, Sleep, Restart, Log Out, and Shut Down with hold-to-confirm progress.
/// Adapts dynamically to requested width (e.g. 220pt for bar widget, 295pt+ for Control Center).
public struct PowerPopoutView: View {
    @ObservedObject private var theme = ThemeStore.shared
    public var width: CGFloat
    public var anchorToControlCenter: Bool
    let onClose: () -> Void

    public init(width: CGFloat = 220, anchorToControlCenter: Bool = false, onClose: @escaping () -> Void) {
        self.width = width
        self.anchorToControlCenter = anchorToControlCenter
        self.onClose = onClose
    }

    public var body: some View {
        PopoutSurfaceContainer(bodyWidth: width, bodyHeight: 290, anchorToControlCenter: anchorToControlCenter) {
            VStack(spacing: 0) {
                // Header
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .foregroundColor(theme.primary)
                Text("Power & Session")
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
            .background(theme.panelHeaderBackground)

            Divider().background(theme.outlineVariant.opacity(0.4))

            VStack(spacing: 8) {
                // Instant Safe Actions
                HStack(spacing: 8) {
                    PowerInstantActionButton(
                        icon: "lock.fill",
                        label: "Lock",
                        tint: theme.primary
                    ) {
                        onClose()
                        ControlCenterController.shared.hide()
                        PowerMenuView.lockScreen()
                    }

                    PowerInstantActionButton(
                        icon: "moon.zzz.fill",
                        label: "Sleep",
                        tint: theme.secondary
                    ) {
                        onClose()
                        ControlCenterController.shared.hide()
                        PowerMenuView.sleepSystem()
                    }
                }

                Divider()
                    .background(theme.outlineVariant.opacity(0.3))
                    .padding(.vertical, 2)

                Text("Hold 1s to Confirm")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(theme.onSurfaceVariant.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                // Disruptive Actions with Hold-To-Confirm
                PowerHoldActionButton(
                    icon: "rectangle.portrait.and.arrow.right",
                    label: "Log Out",
                    tint: theme.warning
                ) {
                    onClose()
                    ControlCenterController.shared.hide()
                    PowerMenuView.logOut()
                }

                PowerHoldActionButton(
                    icon: "arrow.counterclockwise",
                    label: "Restart",
                    tint: theme.warning
                ) {
                    onClose()
                    ControlCenterController.shared.hide()
                    PowerMenuView.restartSystem()
                }

                PowerHoldActionButton(
                    icon: "power",
                    label: "Shut Down",
                    tint: theme.error
                ) {
                    onClose()
                    ControlCenterController.shared.hide()
                    PowerMenuView.shutDownSystem()
                }
            }
            .padding(12)
        }
    }
    }
}

/// Instant tap action button for non-destructive power actions (Lock, Sleep).
private struct PowerInstantActionButton: View {
    let icon: String
    let label: String
    let tint: Color
    let action: () -> Void

    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tint)
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.onSurface)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(theme.surfaceContainerHigh)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

/// Hold-to-confirm action button displaying an animated safety progress ring.
private struct PowerHoldActionButton: View {
    let icon: String
    let label: String
    let tint: Color
    let onConfirm: () -> Void

    @ObservedObject private var theme = ThemeStore.shared
    @State private var isHolding = false
    @State private var hasConfirmed = false
    @State private var progress: CGFloat = 0.0
    @State private var holdTimer: Timer?

    private let holdDuration: TimeInterval = 1.0

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                // Background circle track
                Circle()
                    .stroke(theme.outlineVariant.opacity(0.3), lineWidth: 2)
                    .frame(width: 22, height: 22)

                // Filling progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)

                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isHolding ? tint : theme.onSurface)
            }

            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(theme.onSurface)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isHolding ? tint.opacity(0.12) : theme.surfaceContainerHigh)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHolding ? tint.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if abs(value.translation.width) > 60 || abs(value.translation.height) > 40 {
                        cancelHold()
                    } else if !isHolding && !hasConfirmed {
                        startHold()
                    }
                }
                .onEnded { _ in
                    cancelHold()
                }
        )
    }

    private func startHold() {
        guard !isHolding && !hasConfirmed else { return }
        isHolding = true
        progress = 0.0

        let startTime = CACurrentMediaTime()
        let duration = holdDuration

        holdTimer?.invalidate()
        let timer = Timer(timeInterval: 0.016, repeats: true) { _ in
            Task { @MainActor in
                guard isHolding && !hasConfirmed else { return }
                let elapsed = CACurrentMediaTime() - startTime
                let p = min(1.0, CGFloat(elapsed / duration))
                withAnimation(.linear(duration: 0.016)) {
                    progress = p
                }

                if elapsed >= duration {
                    holdTimer?.invalidate()
                    holdTimer = nil
                    hasConfirmed = true
                    progress = 1.0
                    onConfirm()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func cancelHold() {
        guard !hasConfirmed else { return }
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        withAnimation(.easeOut(duration: 0.2)) {
            progress = 0.0
        }
    }
}
