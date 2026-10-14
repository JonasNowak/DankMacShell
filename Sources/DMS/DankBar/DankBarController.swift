import AppKit
import SwiftUI
import DMSCore

@MainActor
public final class DankBarController {
    public static let shared = DankBarController()

    public let panel: ShellPanel
    public private(set) var isVisible = true

    public static let barHeight: CGFloat = 50

    private init() {
        panel = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: DankBarView())
        reposition()
        setupScreenChangeObserver()
    }

    public func show() {
        reposition()
        panel.orderFront(nil)
        isVisible = true
    }

    public func hide() {
        panel.orderOut(nil)
        isVisible = false
    }

    public func updateBarFrame() {
        reposition()
    }

    public func reposition() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let isBottom = ConfigStore.shared.config.barPosition.lowercased() == "bottom"

        // Tight margins so the bar stretches comfortably across the width of the display
        let marginX: CGFloat = CGFloat(ConfigStore.shared.config.barMarginX)
        let marginY: CGFloat = 8
        let barWidth = screenFrame.width - (marginX * 2)

        let yPos: CGFloat = isBottom ? (screenFrame.minY + marginY) : (screenFrame.maxY - Self.barHeight - marginY)

        let frame = NSRect(
            x: screenFrame.minX + marginX,
            y: yPos,
            width: barWidth,
            height: Self.barHeight
        )

        panel.setFrame(frame, display: true)
    }

    private func setupScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reposition()
            }
        }
    }
}
