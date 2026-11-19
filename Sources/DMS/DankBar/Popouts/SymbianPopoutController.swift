import AppKit
import SwiftUI
import DMSCore

/// Small DankBar popout for the Nokia Belle Sync applet (`symbianApplet`).
/// Shows live device status plus a mini storage overview and a link-style action
/// that opens the `symbian-belle-sync` plugin companion (dms-symbian).
@MainActor
public final class SymbianPopoutController: ObservableObject, PopoutController {
    public static let shared = SymbianPopoutController()

    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    public var popoutID: String { "symbian" }
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

        let bodyWidth: CGFloat = 236
        let bodyHeight: CGFloat = 172

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

        let rootView = SymbianPopoutView(ownerPanel: panel) { [weak self] in
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

/// Popout body for the Nokia Belle Sync bar applet.
public struct SymbianPopoutView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var status = SymbianBarStatus.shared
    let ownerPanel: NSPanel?
    let onClose: () -> Void

    public init(ownerPanel: NSPanel? = nil, onClose: @escaping () -> Void) {
        self.ownerPanel = ownerPanel
        self.onClose = onClose
    }

    public var body: some View {
        PopoutSurfaceContainer(bodyWidth: 236, bodyHeight: 172, ownerPanel: ownerPanel) {
            // Keep the device scan alive while the popout is open even if no bar widget is mounted.
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    if let img = SymbianBarWidget.cachedNokiaImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 18, height: 18)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "phone.and.waveform")
                            .foregroundColor(theme.primary)
                    }
                    Text("Nokia Belle Sync")
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
                    // Connection status row
                    HStack(spacing: 6) {
                        Circle()
                            .fill(status.device != nil ? theme.success : theme.warning)
                            .frame(width: 7, height: 7)
                        Text(status.device?.name ?? "No Nokia C7 connected")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.onSurface)
                            .lineLimit(1)
                        Spacer()
                        if let dev = status.device {
                            Text(dev.driveLetter)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.primary)
                        }
                    }

                    // Mini storage overview (only when a device is mounted)
                    if let dev = status.device {
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { geo in
                                let w = max(10.0, geo.size.width)
                                let usedRatio = max(0.0, min(1.0, dev.usedPercentage))
                                HStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(theme.primary)
                                        .frame(width: max(2.0, w * usedRatio))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(theme.surfaceContainerHighest)
                                        .frame(width: max(0.0, w * (1.0 - usedRatio)))
                                }
                            }
                            .frame(height: 6)
                            .cornerRadius(3)

                            HStack {
                                Text("\(dev.formattedUsedSpace) used")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(theme.onSurfaceVariant)
                                Spacer()
                                Text("\(dev.formattedFreeSpace) free of \(dev.formattedTotalSpace)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(theme.onSurfaceVariant)
                            }
                        }
                    }

                    Divider().background(theme.outlineVariant.opacity(0.3))

                    // Link to the symbian-belle-sync plugin companion
                    Button {
                        onClose()
                        _ = SymbianClient.shared.launchCompanion()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 11, weight: .bold))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Open Belle Sync plugin")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("symbian-belle-sync")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(theme.onSurfaceVariant)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(theme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(theme.primaryContainer.opacity(0.55))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Launch the dms-symbian companion (symbian-belle-sync plugin)")
                }
                .padding(12)
            }
            .onAppear { status.addConsumer() }
            .onDisappear { status.removeConsumer() }
        }
    }
}
