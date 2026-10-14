import AppKit
import SwiftUI

/// Controller for the Clipboard History modal panel.
@MainActor
public final class ClipboardController: ObservableObject {
    public static let shared = ClipboardController()

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
        let visibleFrame = screen.visibleFrame

        let width: CGFloat = 500
        let height: CGFloat = 460
        let rect = NSRect(
            x: visibleFrame.minX + (visibleFrame.width - width) / 2,
            y: visibleFrame.minY + (visibleFrame.height - height) / 2,
            width: width,
            height: height
        )

        let panel = ShellPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating

        let view = ClipboardView { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: view)

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
