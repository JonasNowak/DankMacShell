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

        ConfigStore.shared.$config
            .map { $0.rawSettings["capsLockOsdEnabled"]?.boolValue ?? false }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.setCapsLockMonitoring(enabled: enabled)
            }
            .store(in: &cancellables)
    }

    private func setCapsLockMonitoring(enabled: Bool) {
        if enabled {
            guard flagsMonitor == nil else { return }
            lastCapsLockState = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
            flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] _ in
                Task { @MainActor [weak self] in
                    let isCaps = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
                    guard let self = self, isCaps != self.lastCapsLockState else { return }
                    self.lastCapsLockState = isCaps
                    self.show(type: .capsLock, isMuted: !isCaps, text: isCaps ? "ON" : "OFF")
                }
            }
        } else if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }

    public func show(type: OSDType, value: Double? = nil, isMuted: Bool = false, text: String? = nil) {
        guard ConfigStore.shared.config.rawSettings["osdEnabled"]?.boolValue ?? true else { return }

        let icon = type.iconName(isMuted: isMuted, value: value, text: text)
        let formatted = type.formattedValue(isMuted: isMuted, value: value, text: text)
        let label = (type == .audioOutput || type == .capsLock || type == .idleInhibit) ? "\(type.title): \(formatted)" : type.title
        let progress = type.isGaugeMetric ? (isMuted ? 0.0 : (value ?? 0.0)) : nil

        // Route through DIslandController only when the island is actually able to show OSDs;
        // otherwise present our own floating panel so OSDs are never silently dropped.
        let island = ConfigStore.shared.config.islandSettings
        let islandHandlesOSD = island.instance != .off && island.enabledActivities.contains(IslandActivity.osd.rawValue)
        if islandHandlesOSD {
            DIslandController.shared.triggerOSD(icon: icon, label: label, progress: progress)
        } else {
            presentFallbackOSD(type: type, value: value, isMuted: isMuted, text: text)
        }
    }

    /// Floating fallback OSD pill used when the Dynamic Island is off or OSD is not whitelisted.
    private func presentFallbackOSD(type: OSDType, value: Double?, isMuted: Bool, text: String?) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let host = NSHostingView(rootView: OSDView(type: type, value: value, isMuted: isMuted, text: text))
        let fitted = host.fittingSize
        let w = max(260, fitted.width)
        let h = max(44, fitted.height)
        let frame = NSRect(
            x: screen.frame.minX + (screen.frame.width - w) * 0.5,
            y: screen.frame.maxY - h - 24,
            width: w,
            height: h
        )
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.orderFront(nil)

        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled, let self = self else { return }
            self.panel.orderOut(nil)
        }
    }
}
