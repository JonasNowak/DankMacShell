import AppKit
import SwiftUI
import DMSCore

@MainActor
public final class OSDController {
    public static let shared = OSDController()

    public let panel: ShellPanel
    private var hideTask: Task<Void, Never>?

    private init() {
        panel = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating

        setupListeners()
    }

    private func setupListeners() {
        AudioService.shared.onVolumeChanged = { [weak self] vol, muted in
            Task { @MainActor [weak self] in
                self?.show(type: .volume, value: vol, isMuted: muted)
            }
        }

        BrightnessService.shared.onBrightnessChanged = { [weak self] bright in
            Task { @MainActor [weak self] in
                self?.show(type: .brightness, value: bright)
            }
        }
    }

    public func show(type: OSDType, value: Double, isMuted: Bool = false) {
        guard let screen = NSScreen.main else { return }

        hideTask?.cancel()

        panel.contentView = NSHostingView(rootView: OSDView(type: type, value: value, isMuted: isMuted))

        let width: CGFloat = 260
        let height: CGFloat = 48
        let xPos = screen.frame.midX - (width / 2)
        let yPos = screen.frame.maxY - 120

        panel.setFrame(NSRect(x: xPos, y: yPos, width: width, height: height), display: true)
        panel.orderFront(nil)

        hideTask = Task {
            try? await Task.sleep(for: .milliseconds(1500))
            if !Task.isCancelled {
                self.panel.orderOut(nil)
            }
        }
    }
}
