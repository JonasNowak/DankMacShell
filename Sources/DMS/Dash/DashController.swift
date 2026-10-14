import AppKit
import SwiftUI

/// Controller for the DankDash dashboard modal overlay.
@MainActor
public final class DashController: ObservableObject {
    public static let shared = DashController()

    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false

    private init() {}

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        guard !isVisible else { return }

        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame

        let panel = ShellPanel(
            contentRect: screenRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.ignoresMouseEvents = false

        let dashView = DashView { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: dashView)

        self.panel = panel
        self.isVisible = true

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func hide() {
        guard isVisible else { return }
        panel?.orderOut(nil)
        panel = nil
        isVisible = false
    }
}
