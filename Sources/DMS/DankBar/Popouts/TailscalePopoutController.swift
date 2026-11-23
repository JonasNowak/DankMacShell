import AppKit
import SwiftUI
import DMSCore

/// Dedicated DankBar popout for Tailscale mesh VPN: live status badge, exit node
/// picker, and mesh peers. Wraps `VPNDetailPage` like `AudioPopoutController` wraps
/// `AudioDetailPage`.
@MainActor
public final class TailscalePopoutController: ObservableObject, PopoutController {
    public static let shared = TailscalePopoutController()

    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    public var popoutID: String { "tailscale" }
    public var popoutPanel: ShellPanel? { panel }
    public var isPopoutVisible: Bool { isVisible }
    public func hidePopout() { hide() }

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

        // Close peer popouts and non-popout DMS panels
        PopoutCoordinator.shared.dismissAll(except: popoutID)
        DashController.shared.hide()
        ProcessListController.shared.hide()
        ControlCenterController.shared.hide()

        // Close any existing panel BEFORE creating a new one (fixes leaked ghost panels on double-show)
        if let existing = panel {
            existing.orderOut(nil)
            panel = nil
        }

        let bodyWidth: CGFloat = 350
        let bodyHeight: CGFloat = 440

        let rect = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: bodyHeight,
            anchorX: anchorX,
            screen: screen
        )

        let panel = ShellPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.onEscape = { [weak self] in
            self?.hide()
        }

        let rootView = TailscalePopoutView(ownerPanel: panel) { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: rootView)

        self.panel = panel
        self.isVisible = true

        PopoutCoordinator.shared.register(self)
        PopoutAnimationHelper.animateIn(panel: panel, targetFrame: rect, screen: screen)
        installClickMonitors()
    }

    public func hide() {
        guard isVisible else { return }
        removeClickMonitors()
        PopoutCoordinator.shared.unregister(popoutID)
        isVisible = false

        let panelToClose = self.panel
        let screen = panelToClose?.screen ?? NSScreen.main
        self.panel = nil

        PopoutAnimationHelper.animateOut(panel: panelToClose, screen: screen)
    }

    private func installClickMonitors() {
        removeClickMonitors()
        let handler: (NSEvent) -> NSEvent? = { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self = self, self.isVisible else { return }
                let clickLoc = NSEvent.mouseLocation
                if let p = self.panel, NSMouseInRect(clickLoc, p.frame, false) { return }
                if PopoutCoordinator.shared.isPointInsideAnyBar(clickLoc) { return }
                self.hide()
            }
            return event
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: handler)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { event in _ = handler(event) })
    }

    private func removeClickMonitors() {
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}

/// M3 popout view wrapping VPNDetailPage with a Tailscale header (350x440).
public struct TailscalePopoutView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var tailscale = TailscaleService.shared
    let ownerPanel: NSPanel?
    let onClose: () -> Void

    public init(ownerPanel: NSPanel? = nil, onClose: @escaping () -> Void) {
        self.ownerPanel = ownerPanel
        self.onClose = onClose
    }

    public var body: some View {
        PopoutSurfaceContainer(bodyWidth: 350, bodyHeight: 440, ownerPanel: ownerPanel) {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(ThemeStore.shared.font(size: 13, weight: .bold))
                        .foregroundColor(theme.primary)
                    Text("Tailscale & VPN")
                        .font(ThemeStore.shared.font(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(theme.onSurface)
                    statusBadge
                    Spacer()
                    Button(action: { tailscale.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                            .foregroundColor(theme.onSurfaceVariant)
                            .frame(width: 22, height: 22)
                            .background(theme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Refresh")
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                            .foregroundColor(theme.onSurfaceVariant)
                            .frame(width: 22, height: 22)
                            .background(theme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.panelHeaderBackground)

                Divider().background(theme.outlineVariant.opacity(0.4))

                ScrollView(.vertical, showsIndicators: false) {
                    VPNDetailPage()
                        .padding(10)
                }
            }
        }
    }

    private var statusBadge: some View {
        let connected = tailscale.isInstalled && tailscale.isConnected
        return Text(connected ? "Connected" : "Disconnected")
            .font(ThemeStore.shared.font(size: 9, weight: .bold))
            .foregroundColor(connected ? theme.onPrimaryContainer : theme.onSurfaceVariant)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(connected ? theme.primaryContainer : theme.surfaceContainerHigh)
            .clipShape(Capsule())
    }
}
