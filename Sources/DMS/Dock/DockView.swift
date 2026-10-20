import SwiftUI
import AppKit
import DMSCore

/// Master Desktop Dock View implementing magnification physics,
/// compact and taskbar layouts, edit mode, and dynamic icon proximity scaling.
public struct DockView: View {
    public let config: DockConfig
    public let onEditToggle: (() -> Void)?

    @ObservedObject private var theme = ThemeStore.shared
    private var appsService = RunningAppsService.shared

    @State private var mouseLocation: CGPoint? = nil
    @State private var hoveredItemIndex: Int? = nil
    @State private var isEditMode: Bool = false

    public init(
        config: DockConfig,
        onEditToggle: (() -> Void)? = nil
    ) {
        self.config = config
        self.onEditToggle = onEditToggle
    }

    private var allDockApps: [AppItem] {
        appsService.dockApps
    }

    private var visibleApps: [AppItem] {
        if config.maxVisibleApps > 0 && allDockApps.count > config.maxVisibleApps {
            return Array(allDockApps.prefix(config.maxVisibleApps))
        }
        return allDockApps
    }

    private var overflowApps: [AppItem] {
        if config.maxVisibleApps > 0 && allDockApps.count > config.maxVisibleApps {
            return Array(allDockApps.dropFirst(config.maxVisibleApps))
        }
        return []
    }

    // Total interactive units for proximity calculation
    private var unitCount: Int {
        var count = visibleApps.count
        if config.launcherEnabled { count += 1 }
        if !overflowApps.isEmpty { count += 1 }
        if config.showTrash { count += 1 }
        return count
    }

    private func scaleForUnit(at index: Int, totalUnits: Int) -> Double {
        guard config.magnification, let mouse = mouseLocation, totalUnits > 0 else {
            return 1.0
        }

        let itemPitch = Double(config.iconSize + config.itemSpacing)
        let startOffset = itemPitch / 2.0
        let itemCenter = startOffset + Double(index) * itemPitch

        let mousePos = config.isVertical ? Double(mouse.y) : Double(mouse.x)
        let dist = abs(mousePos - itemCenter)

        return DockMagnificationEngine.magnificationScale(
            dist: dist,
            baseSize: Double(config.iconSize),
            maxScalePercent: config.magnificationScale,
            profile: config.magnificationProfile
        )
    }

    public var body: some View {
        VStack(spacing: 8) {
            if isEditMode && config.position != 0 {
                DockEditChrome(
                    title: config.name,
                    onAddWidget: { SettingsController.shared.show() },
                    onSettings: { SettingsController.shared.show() },
                    onDone: { withAnimation { isEditMode = false } }
                )
            }

            dockContent
                .background(dockBackground)
                .clipShape(dockShape)
                .overlay(dockBorder)
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)

            if isEditMode && config.position == 0 {
                DockEditChrome(
                    title: config.name,
                    onAddWidget: { SettingsController.shared.show() },
                    onSettings: { SettingsController.shared.show() },
                    onDone: { withAnimation { isEditMode = false } }
                )
            }
        }
        .contextMenu {
            Button(isEditMode ? "Exit Edit Mode" : "Edit Dock") {
                withAnimation { isEditMode.toggle() }
            }
            Button("Dock Settings") {
                SettingsController.shared.show()
            }
        }
    }

    // MARK: - Dock Content Layout
    @ViewBuilder
    private var dockContent: some View {
        if config.isVertical {
            VStack(spacing: CGFloat(config.itemSpacing)) {
                itemsList
            }
            .padding(CGFloat(config.spacing))
            .trackingMouse { location in
                mouseLocation = location
            }
        } else {
            HStack(spacing: CGFloat(config.itemSpacing)) {
                itemsList
            }
            .padding(CGFloat(config.spacing))
            .trackingMouse { location in
                mouseLocation = location
            }
        }
    }

    // MARK: - Ordered Dock Items
    @ViewBuilder
    private var itemsList: some View {
        var currentIndex = 0

        // 1. Launcher button
        if config.launcherEnabled {
            let idx = currentIndex
            DockLauncherButton(
                config: config,
                scale: scaleForUnit(at: idx, totalUnits: unitCount),
                isHovered: hoveredItemIndex == idx
            )
            .onHover { h in if h { hoveredItemIndex = idx } else if hoveredItemIndex == idx { hoveredItemIndex = nil } }
            let _ = { currentIndex += 1 }()
        }

        // 2. Applications
        ForEach(Array(visibleApps.enumerated()), id: \.element.bundleID) { offset, app in
            let idx = currentIndex + offset
            DockAppButton(
                app: app,
                config: config,
                scale: scaleForUnit(at: idx, totalUnits: unitCount),
                isHovered: hoveredItemIndex == idx,
                onSelect: {
                    appsService.activate(app: app)
                }
            )
            .onHover { h in if h { hoveredItemIndex = idx } else if hoveredItemIndex == idx { hoveredItemIndex = nil } }
        }
        let _ = { currentIndex += visibleApps.count }()

        // 3. Overflow tray
        if !overflowApps.isEmpty {
            let idx = currentIndex
            DockOverflowButton(
                hiddenApps: overflowApps,
                config: config,
                scale: scaleForUnit(at: idx, totalUnits: unitCount),
                isHovered: hoveredItemIndex == idx
            )
            .onHover { h in if h { hoveredItemIndex = idx } else if hoveredItemIndex == idx { hoveredItemIndex = nil } }
            let _ = { currentIndex += 1 }()
        }

        // 4. Trash button
        if config.showTrash {
            let idx = currentIndex
            DockTrashButton(
                config: config,
                scale: scaleForUnit(at: idx, totalUnits: unitCount),
                isHovered: hoveredItemIndex == idx
            )
            .onHover { h in if h { hoveredItemIndex = idx } else if hoveredItemIndex == idx { hoveredItemIndex = nil } }
            let _ = { currentIndex += 1 }()
        }
    }

    // MARK: - Surface Background & Styling
    private var dockBackground: some View {
        ZStack {
            VisualEffectBlur(material: .headerView, blendingMode: .withinWindow)
            theme.surfaceContainer.opacity(config.transparency)
        }
    }

    private var dockShape: some Shape {
        RoundedRectangle(cornerRadius: CGFloat(config.iconSize) / 2.0 + CGFloat(config.spacing), style: .continuous)
    }

    @ViewBuilder
    private var dockBorder: some View {
        if config.borderEnabled {
            RoundedRectangle(cornerRadius: CGFloat(config.iconSize) / 2.0 + CGFloat(config.spacing), style: .continuous)
                .stroke(
                    Color(hex: config.borderColor.starts(with: "#") ? config.borderColor : "#FFFFFF").opacity(config.borderOpacity),
                    lineWidth: CGFloat(config.borderThickness)
                )
        }
    }
}

// MARK: - Mouse Tracking NSViewRepresentable
private struct MouseTrackingView: NSViewRepresentable {
    let onMove: (CGPoint?) -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onMove = onMove
    }

    final class TrackingNSView: NSView {
        var onMove: ((CGPoint?) -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
            let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]
            let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseMoved(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            onMove?(point)
        }

        override func mouseEntered(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            onMove?(point)
        }

        override func mouseExited(with event: NSEvent) {
            onMove?(nil)
        }
    }
}

extension View {
    fileprivate func trackingMouse(onMove: @escaping (CGPoint?) -> Void) -> some View {
        overlay(MouseTrackingView(onMove: onMove))
    }
}
