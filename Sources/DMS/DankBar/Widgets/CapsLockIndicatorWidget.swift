import SwiftUI
import AppKit
import DMSCore

/// Caps Lock status warning badge, visible only when active.
/// Complies with `docs/spec/20-bar-widgets.md` `capsLockIndicator`.
public struct CapsLockIndicatorWidget: View {
    public var isVertical: Bool
    @ObservedObject private var theme = ThemeStore.shared
    @State private var isCapsLockOn: Bool = false
    @State private var localMonitor: Any? = nil
    @State private var globalMonitor: Any? = nil

    public init(isVertical: Bool = false) {
        self.isVertical = isVertical
    }

    public var body: some View {
        // Always-mounted outer ZStack so the flagsChanged monitors start even when
        // Caps Lock is off at launch (the Group below may render nothing).
        ZStack {
            Group {
                if isCapsLockOn {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.capslock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.onPrimary)
                        if !isVertical {
                            Text("CAPS")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(theme.onPrimary)
                        }
                    }
                    .padding(.horizontal, isVertical ? 0 : 6)
                    .frame(width: isVertical ? 28 : nil, height: 28)
                    .background(theme.primary)
                }
            }
        }
        .onAppear {
            checkCapsLock()
            setupMonitor()
        }
        .onDisappear {
            teardownMonitor()
        }
    }

    private func checkCapsLock() {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        self.isCapsLockOn = flags.contains(.maskAlphaShift)
    }

    private func setupMonitor() {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                checkCapsLock()
                return event
            }
        }
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { _ in
                Task { @MainActor in
                    checkCapsLock()
                }
            }
        }
    }

    private func teardownMonitor() {
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            localMonitor = nil
        }
        if let global = globalMonitor {
            NSEvent.removeMonitor(global)
            globalMonitor = nil
        }
    }
}
