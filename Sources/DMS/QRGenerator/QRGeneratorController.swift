import AppKit
import SwiftUI

/// Controller for the QR Code Generator modal panel.
@MainActor
public final class QRGeneratorController: ObservableObject {
    public static let shared = QRGeneratorController()

    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false

    private init() {}

    public func toggle(text: String? = nil) {
        if isVisible {
            hide()
        } else {
            show(text: text)
        }
    }

    public func show(text: String? = nil) {
        guard !isVisible else { return }

        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        let width: CGFloat = 400
        let height: CGFloat = 420
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

        let view = QRGeneratorView(initialText: text) { [weak self] in
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
