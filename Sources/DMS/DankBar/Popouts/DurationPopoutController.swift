import AppKit
import SwiftUI
import DMSCore

/// Dedicated Bar Popout for Idle Inhibit (caffeinate) with timed duration presets and live countdown.
/// Complies with `docs/spec/20-bar-widgets.md` `DurationPopout.qml`.
@MainActor
public final class DurationPopoutController: ObservableObject, PopoutController {
    public static let shared = DurationPopoutController()

    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    public var popoutID: String { "duration" }
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

        let bodyWidth: CGFloat = 220
        let bodyHeight: CGFloat = 270

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

        let rootView = DurationPopoutView(ownerPanel: panel) { [weak self] in
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

/// M3 popout view for Sleep Inhibit presets and remaining countdown readout.
public struct DurationPopoutView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared
    let ownerPanel: NSPanel?
    let onClose: () -> Void

    public init(ownerPanel: NSPanel? = nil, onClose: @escaping () -> Void) {
        self.ownerPanel = ownerPanel
        self.onClose = onClose
    }

    public var body: some View {
        PopoutSurfaceContainer(bodyWidth: 220, bodyHeight: 270, ownerPanel: ownerPanel) {
            VStack(spacing: 0) {
                // Header
            HStack(spacing: 8) {
                Image(systemName: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .foregroundColor(inhibit.isInhibited ? theme.primary : theme.onSurfaceVariant)
                Text("Sleep Inhibit")
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

            VStack(spacing: 12) {
                // Status card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(inhibit.isInhibited ? "System Awake" : "Default Sleep")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(inhibit.isInhibited ? theme.primary : theme.onSurface)

                        if let remaining = inhibit.formattedRemainingTime {
                            Text("Expires in \(remaining)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.secondary)
                        } else if inhibit.isInhibited {
                            Text("Indefinite (no timer)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.onSurfaceVariant)
                        } else {
                            Text("Standard macOS power management")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(theme.onSurfaceVariant)
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(theme.surfaceContainerHighest.opacity(0.6))
                .cornerRadius(10)

                // Presets Grid (2 columns)
                let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(IdleInhibitPreset.allCases) { preset in
                        let isSelected = inhibit.isInhibited && inhibit.activePreset == preset
                        Button {
                            inhibit.enable(preset: preset)
                        } label: {
                            Text(preset.shortLabel)
                                .font(.system(size: 11, weight: isSelected ? .bold : .semibold, design: .rounded))
                                .foregroundColor(isSelected ? theme.onPrimary : theme.onSurface)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(isSelected ? theme.primary : theme.surfaceContainerHigh)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Master Toggle / Turn Off Button
                if inhibit.isInhibited {
                    Button {
                        inhibit.disable()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "power")
                                .font(.system(size: 11, weight: .bold))
                            Text("Disable Inhibit")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(theme.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(theme.error.opacity(0.12))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }
    }
}
