import AppKit
import SwiftUI
import DMSCore

/// Dedicated DankBar popout for the Pomodoro focus/break timer: circular progress
/// ring, transport controls, quick presets, and a Dynamic Island shortcut.
@MainActor
public final class PomodoroPopoutController: ObservableObject, PopoutController {
    public static let shared = PomodoroPopoutController()

    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    public var popoutID: String { "pomodoro" }
    public var popoutPanel: ShellPanel? { panel }
    public var isPopoutVisible: Bool { isVisible }
    public func hidePopout() { hide() }

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

        // Close peer popouts and non-popout DMS panels
        PopoutCoordinator.shared.dismissAll(except: popoutID)
        DashController.shared.hide()
        ProcessListController.shared.hide()
        ControlCenterController.shared.hide()

        // Close any existing panel BEFORE creating a new one (fixes leaked ghost panels on double-show)
        if let existing = panel {
            existing.orderOut(nil)
            panel = nil
        }

        let bodyWidth: CGFloat = 300
        let bodyHeight: CGFloat = 370

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
        panel.onEscape = { [weak self] in
            self?.hide()
        }

        let rootView = PomodoroPopoutView(ownerPanel: panel) { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: rootView)

        self.panel = panel
        self.isVisible = true

        PopoutCoordinator.shared.register(self)
        PopoutAnimationHelper.animateIn(panel: panel, targetFrame: rect, screen: screen)
        installClickMonitors()
    }

    public func hide() {
        guard isVisible else { return }
        removeClickMonitors()
        PopoutCoordinator.shared.unregister(popoutID)
        isVisible = false

        let panelToClose = self.panel
        let screen = panelToClose?.screen ?? NSScreen.main
        self.panel = nil

        PopoutAnimationHelper.animateOut(panel: panelToClose, screen: screen)
    }

    private func installClickMonitors() {
        removeClickMonitors()
        let handler: (NSEvent) -> NSEvent? = { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self = self, self.isVisible else { return }
                let clickLoc = NSEvent.mouseLocation
                if let p = self.panel, NSMouseInRect(clickLoc, p.frame, false) { return }
                if PopoutCoordinator.shared.isPointInsideAnyBar(clickLoc) { return }
                self.hide()
            }
            return event
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: handler)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { event in _ = handler(event) })
    }

    private func removeClickMonitors() {
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}

/// M3 popout view for the Pomodoro timer (300x370).
public struct PomodoroPopoutView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var pomodoro = PomodoroService.shared
    let ownerPanel: NSPanel?
    let onClose: () -> Void

    public init(ownerPanel: NSPanel? = nil, onClose: @escaping () -> Void) {
        self.ownerPanel = ownerPanel
        self.onClose = onClose
    }

    public var body: some View {
        PopoutSurfaceContainer(bodyWidth: 300, bodyHeight: 370, ownerPanel: ownerPanel) {
            VStack(spacing: 0) {
                header
                Divider().background(theme.outlineVariant.opacity(0.4))

                VStack(spacing: 12) {
                    progressRing
                    transportControls
                    presetsRow
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Spacer(minLength: 0)

                Divider().background(theme.outlineVariant.opacity(0.4))

                Button(action: {
                    DIslandController.shared.open(activity: .timer)
                    onClose()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "capsule.portrait.fill")
                            .font(ThemeStore.shared.font(size: 11, weight: .bold))
                        Text("Show in Dynamic Island")
                            .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                    }
                    .foregroundColor(theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(theme.surfaceContainerHigh)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(ThemeStore.shared.font(size: 13, weight: .bold))
                .foregroundColor(theme.primary)
            Text("Pomodoro Focus")
                .font(ThemeStore.shared.font(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(theme.onSurface)
            Text("\(pomodoro.completedSessions) done")
                .font(ThemeStore.shared.font(size: 9, weight: .bold))
                .foregroundColor(theme.onPrimaryContainer)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.primaryContainer)
                .clipShape(Capsule())
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                    .foregroundColor(theme.onSurfaceVariant)
                    .frame(width: 22, height: 22)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.panelHeaderBackground)
    }

    // MARK: - Progress ring + countdown

    private var progressRing: some View {
        let ringColor = pomodoro.isBreak ? theme.secondary : theme.primary
        return ZStack {
            Circle()
                .stroke(theme.outlineVariant.opacity(0.35), lineWidth: 10)
            Circle()
                .trim(from: 0, to: pomodoro.progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: pomodoro.progress)
            VStack(spacing: 4) {
                Text(pomodoro.formattedRemaining)
                    .font(ThemeStore.shared.font(size: 34, weight: .bold, mono: true))
                    .foregroundColor(theme.onSurface)
                    .monospacedDigit()
                Text(pomodoro.phaseLabel)
                    .font(ThemeStore.shared.font(size: 10, weight: .bold))
                    .foregroundColor(ringColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(ringColor.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
        .frame(width: 150, height: 150)
    }

    // MARK: - Transport controls

    private var transportControls: some View {
        HStack(spacing: 8) {
            Button(action: { pomodoro.toggleStartPause() }) {
                HStack(spacing: 6) {
                    Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                        .font(ThemeStore.shared.font(size: 12, weight: .bold))
                    Text(pomodoro.isRunning ? "Pause" : "Start")
                        .font(ThemeStore.shared.font(size: 12, weight: .bold))
                }
                .foregroundColor(theme.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(theme.primary)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Button(action: { pomodoro.reset() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(ThemeStore.shared.font(size: 12, weight: .bold))
                    .foregroundColor(theme.onSurfaceVariant)
                    .frame(width: 38, height: 38)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Reset")

            Button(action: { pomodoro.skipPhase() }) {
                Image(systemName: "forward.end.fill")
                    .font(ThemeStore.shared.font(size: 12, weight: .bold))
                    .foregroundColor(theme.onSurfaceVariant)
                    .frame(width: 38, height: 38)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Skip Phase")
        }
    }

    // MARK: - Quick presets

    private var presetsRow: some View {
        HStack(spacing: 6) {
            presetButton(title: "25/5", subtitle: "Classic", work: 25, breakMins: 5)
            presetButton(title: "50/10", subtitle: "Deep Work", work: 50, breakMins: 10)
            presetButton(title: "15/3", subtitle: "Sprint", work: 15, breakMins: 3)
        }
    }

    private func presetButton(title: String, subtitle: String, work: Int, breakMins: Int) -> some View {
        let isActive = pomodoro.workMinutes == work && pomodoro.breakMinutes == breakMins
        return Button(action: { pomodoro.applyPreset(workMinutes: work, breakMinutes: breakMins) }) {
            VStack(spacing: 1) {
                Text(title)
                    .font(ThemeStore.shared.font(size: 11, weight: .bold, mono: true))
                Text(subtitle)
                    .font(ThemeStore.shared.font(size: 8, weight: .medium))
            }
            .foregroundColor(isActive ? theme.onPrimaryContainer : theme.onSurfaceVariant)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isActive ? theme.primaryContainer : theme.surfaceContainerHigh)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
