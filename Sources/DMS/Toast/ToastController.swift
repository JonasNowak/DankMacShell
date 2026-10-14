import AppKit
import SwiftUI
import DMSCore

@MainActor
public final class ToastController {
    public static let shared = ToastController()

    public let panel: ShellPanel

    private init() {
        panel = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.contentView = NSHostingView(rootView: ToastOverlayView())
        reposition()
    }

    public func reposition() {
        guard let screen = NSScreen.main else { return }
        let width: CGFloat = 320
        let height: CGFloat = 60
        let xPos = screen.frame.maxX - width - 20
        let yPos = screen.frame.maxY - height - 20

        panel.setFrame(NSRect(x: xPos, y: yPos, width: width, height: height), display: true)
        panel.orderFront(nil)
    }
}
