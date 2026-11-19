import AppKit
import SwiftUI
import DMSCore

/// Dedicated Bar Popout for Color Sampling with quick eyedropper trigger and the last 12 sampled color swatches.
/// Complies with `docs/spec/20-bar-widgets.md` `ColorPickerPopout.qml`.
@MainActor
public final class ColorPickerPopoutController: ObservableObject, PopoutController {
    public static let shared = ColorPickerPopoutController()

    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    public var popoutID: String { "colorPicker" }
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

        let bodyWidth: CGFloat = 240
        let bodyHeight: CGFloat = 280

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

        let rootView = ColorPickerPopoutView(ownerPanel: panel) { [weak self] in
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

/// M3 popout view for eyedropper tool and recent color swatches.
public struct ColorPickerPopoutView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var colorPicker = ColorPickerService.shared
    let ownerPanel: NSPanel?
    let onClose: () -> Void

    public init(ownerPanel: NSPanel? = nil, onClose: @escaping () -> Void) {
        self.ownerPanel = ownerPanel
        self.onClose = onClose
    }

    public var body: some View {
        PopoutSurfaceContainer(bodyWidth: 240, bodyHeight: 280, ownerPanel: ownerPanel) {
            VStack(spacing: 0) {
                // Header
            HStack(spacing: 8) {
                Image(systemName: "eyedropper.halffull")
                    .foregroundColor(theme.primary)
                Text("Color Picker")
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
                // Eyedropper Trigger Action Button
                Button {
                    colorPicker.sampleColor()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eyedropper")
                            .font(.system(size: 12, weight: .bold))
                        Text("Pick Screen Color")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(theme.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(theme.primary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // Active Color Display Card
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: colorPicker.selectedColor))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(theme.outlineVariant.opacity(0.6), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(colorPicker.hexCode)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.onSurface)
                        Text(colorPicker.rgbString)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                        Text(colorPicker.hslString)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                    }

                    Spacer()

                    Button {
                        colorPicker.copyColorToClipboard(colorPicker.hexCode)
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.primary)
                            .frame(width: 28, height: 28)
                            .background(theme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Copy Hex Code")
                }
                .padding(8)
                .background(theme.surfaceContainerHighest.opacity(0.5))
                .cornerRadius(10)

                // Recent Swatches Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent Colors (Click to Copy)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.onSurfaceVariant)

                    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(colorPicker.recentColors.prefix(12), id: \.self) { hex in
                            Button {
                                colorPicker.copyColorToClipboard(hex)
                            } label: {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(hex: hex))
                                    .frame(height: 24)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(theme.outlineVariant.opacity(0.4), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Copy \(hex)")
                        }
                    }
                }
            }
            .padding(12)
        }
    }
    }
}
