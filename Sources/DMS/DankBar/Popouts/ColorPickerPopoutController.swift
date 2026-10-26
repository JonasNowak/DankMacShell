import AppKit
import SwiftUI
import DMSCore

/// Dedicated Bar Popout for Color Sampling with quick eyedropper trigger and the last 12 sampled color swatches.
/// Complies with `docs/spec/20-bar-widgets.md` `ColorPickerPopout.qml`.
@MainActor
public final class ColorPickerPopoutController: ObservableObject {
    public static let shared = ColorPickerPopoutController()

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
        DurationPopoutController.shared.hide()
        PowerPopoutController.shared.hide()
        ProcessListController.shared.hide()
        ControlCenterController.shared.hide()

        let popoutWidth: CGFloat = 240
        let popoutHeight: CGFloat = 280
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

        let rootView = ColorPickerPopoutView { [weak self] in
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

/// M3 popout view for eyedropper tool and recent color swatches.
public struct ColorPickerPopoutView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var colorPicker = ColorPickerService.shared
    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
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
            .background(theme.surfaceContainerHigh)

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
        .frame(width: 240, height: 280)
        .background(theme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.outlineVariant.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
    }
}
