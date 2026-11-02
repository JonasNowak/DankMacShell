import AppKit
import SwiftUI
import Combine
import DMSCore

@MainActor
public final class OSDController {
    public static let shared = OSDController()

    public let panel: ShellPanel
    private var hideTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var flagsMonitor: Any?
    private var lastCapsLockState: Bool = false

    private init() {
        panel = ShellPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating

        lastCapsLockState = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)

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

        AudioService.shared.onMicMuteChanged = { [weak self] muted in
            Task { @MainActor [weak self] in
                self?.show(type: .micVolume, value: muted ? 0.0 : 1.0, isMuted: muted)
            }
        }

        AudioService.shared.onDefaultOutputChanged = { [weak self] name, icon in
            Task { @MainActor [weak self] in
                self?.show(type: .audioOutput, text: name)
            }
        }

        IdleInhibitService.shared.$isInhibited
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] isInhibited in
                self?.show(type: .idleInhibit, isMuted: !isInhibited, text: isInhibited ? "Awake" : "Normal")
            }
            .store(in: &cancellables)

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] _ in
            Task { @MainActor [weak self] in
                let isCaps = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
                guard let self = self, isCaps != self.lastCapsLockState else { return }
                self.lastCapsLockState = isCaps
                self.show(type: .capsLock, isMuted: !isCaps, text: isCaps ? "ON" : "OFF")
            }
        }
    }

    public func show(type: OSDType, value: Double? = nil, isMuted: Bool = false, text: String? = nil) {
        guard ConfigStore.shared.config.rawSettings["osdEnabled"]?.boolValue ?? true else { return }

        // Route directly through DIslandController (Dynamic Island swallows the OSD)
        let icon = type.iconName(isMuted: isMuted, value: value, text: text)
        let formatted = type.formattedValue(isMuted: isMuted, value: value, text: text)
        let label = (type == .audioOutput || type == .capsLock || type == .idleInhibit) ? "\(type.title): \(formatted)" : type.title
        let progress = type.isGaugeMetric ? (isMuted ? 0.0 : (value ?? 0.0)) : nil
        DIslandController.shared.triggerOSD(icon: icon, label: label, progress: progress)
    }
}
