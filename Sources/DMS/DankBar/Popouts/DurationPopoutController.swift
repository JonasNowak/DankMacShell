import AppKit
import SwiftUI
import DMSCore

/// Dedicated Bar Popout for Idle Inhibit (caffeinate) with timed duration presets and live countdown.
/// Complies with `docs/spec/20-bar-widgets.md` `DurationPopout.qml`.
@MainActor
public final class DurationPopoutController: ObservableObject {
    public static let shared = DurationPopoutController()

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
        BatteryPopoutController.shared.hide()
        ColorPickerPopoutController.shared.hide()
        SymbianPopoutController.shared.hide()
        PowerPopoutController.shared.hide()
        ProcessListController.shared.hide()
        ControlCenterController.shared.hide()

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

        let rootView = DurationPopoutView { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: rootView)

        self.panel = panel
        self.isVisible = true

        PopoutAnimationHelper.animateIn(panel: panel, targetFrame: rect, screen: screen)
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

/// M3 popout view for Sleep Inhibit presets and remaining countdown readout.
public struct DurationPopoutView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared
    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        PopoutSurfaceContainer(bodyWidth: 220, bodyHeight: 270) {
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
