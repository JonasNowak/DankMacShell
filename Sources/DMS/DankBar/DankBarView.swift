import SwiftUI
import AppKit
import Combine
import Carbon.HIToolbox
import DMSCore

/// Multi-axis, multi-monitor DankBar view with Mac notch safe-zone reflow, Dynamic Island coordination,
/// true-center collision avoidance, and M3 segment roles.
/// Strictly adheres to `docs/spec/19-bar-core.md` and `docs/spec/20-bar-widgets.md`.
public struct DankBarView: View {
    public var barConfig: BarConfig
    public var notchGeometry: ScreenNotchGeometry?
    public var screenIndex: Int

    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var workspace = WorkspaceService.shared
    private let telemetry = TelemetryService.shared
    private let wifi = WiFiService.shared
    private let audio = AudioService.shared
    private let battery = BatteryService.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared
    @ObservedObject private var configStore = ConfigStore.shared
    @ObservedObject private var island = DIslandController.shared

    @State private var leftSectionSize: CGFloat = 200
    @State private var rightSectionSize: CGFloat = 300
    @State private var centerSectionSize: CGFloat = 180

    public init(
        barConfig: BarConfig = .default,
        notchGeometry: ScreenNotchGeometry? = nil,
        screenIndex: Int = 0
    ) {
        self.barConfig = barConfig
        self.notchGeometry = notchGeometry
        self.screenIndex = screenIndex
    }

    private var activeConfig: BarConfig {
        configStore.config.barConfigs.first(where: { $0.id == barConfig.id }) ?? barConfig
    }

    public var isVertical: Bool {
        activeConfig.isVertical
    }

    private var effectiveNotch: ScreenNotchGeometry {
        if let provided = notchGeometry {
            if activeConfig.simulateNotch && !provided.hasNotch {
                return ScreenNotchGeometry.fromScreenMeasurements(
                    screenID: "simulated",
                    screenWidth: provided.screenWidth,
                    screenHeight: provided.screenHeight,
                    safeAreaTop: 0,
                    auxiliaryLeftWidth: nil,
                    auxiliaryRightMinX: nil,
                    auxiliaryRightWidth: nil,
                    simulateNotch: true,
                    simulatedNotchWidth: activeConfig.simulatedNotchWidth,
                    simulatedNotchHeight: activeConfig.simulatedNotchHeight
                )
            }
            return provided
        }
        let screen = (screenIndex < NSScreen.screens.count) ? NSScreen.screens[screenIndex] : NSScreen.main
        return screen?.extractNotchGeometry(barConfig: activeConfig)
            ?? ScreenNotchGeometry.standardMonitor(width: 1440, height: 900)
    }

    private var isTopNotchedMode: Bool {
        !isVertical &&
        activeConfig.position.lowercased() == "top" &&
        activeConfig.adaptToNotch &&
        (effectiveNotch.hasNotch || (island.settings.instance != .off && (island.settings.instance == .notch || island.settings.instance == .mainBar)))
    }

    private var effectiveCornerStyle: BarCornerStyle {
        if activeConfig.cornerStyle == .square || (activeConfig.autoSquareAttachedCorners && activeConfig.margin == 0 && activeConfig.cornerStyle != .gothic) {
            return .square
        }
        return activeConfig.cornerStyle
    }

    private var resolvedBarCornerRadius: CGFloat {
        if effectiveCornerStyle == .square {
            return 0
        }
        if activeConfig.cornerRadius >= 0 {
            return CGFloat(activeConfig.cornerRadius)
        }
        return theme.scaledRadius(24)
    }

    private func barContainerShape(isLeftWing: Bool? = nil, isRightWing: Bool? = nil) -> BarGothCornerShape {
        BarGothCornerShape(
            position: activeConfig.position,
            cornerStyle: effectiveCornerStyle,
            cornerRadius: resolvedBarCornerRadius,
            filletRadius: CGFloat(activeConfig.gothFilletRadius),
            isVertical: isVertical,
            isLeftWing: isLeftWing,
            isRightWing: isRightWing
        )
    }

    private var resolvedBorderColor: Color {
        if let customHex = activeConfig.borderColor, !customHex.isEmpty {
            return Color(hex: customHex)
        }
        return theme.outlineVariant.opacity(max(0.2, theme.surfaceTokens.outlineOpacity * 2.2))
    }

    public var body: some View {
        GeometryReader { proxy in
            let totalLength = isVertical ? proxy.size.height : proxy.size.width

            if isTopNotchedMode {
                notchedHorizontalBarContent(totalLength: totalLength)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let shape = barContainerShape()
                ZStack {
                    if isVertical {
                        verticalBarContent(totalLength: totalLength)
                    } else {
                        horizontalBarContent(totalLength: totalLength)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(barBackground)
                .clipShape(shape)
                .overlay(
                    Group {
                        if activeConfig.borderEnabled && activeConfig.backgroundStyle.lowercased() != "island" {
                            shape.stroke(
                                resolvedBorderColor,
                                lineWidth: CGFloat(max(0.0, activeConfig.borderWidth))
                            )
                        }
                    }
                )
                .shadow(
                    color: theme.shadowTokens.enabled ? theme.shadow.opacity(theme.shadowTokens.opacity * 0.7) : .clear,
                    radius: theme.shadowTokens.enabled ? CGFloat(theme.shadowTokens.blurRadius) : 0,
                    x: 0,
                    y: theme.shadowTokens.enabled ? CGFloat(theme.shadowTokens.offsetY) : 0
                )
            }
        }
    }

    // MARK: - Bar Background
    @ViewBuilder
    private var barBackground: some View {
        let style = activeConfig.backgroundStyle.lowercased()
        if style == "transparent" || style == "island" {
            Color.clear
        } else if style == "glass" || activeConfig.transparency < 1.0 || configStore.config.barTransparent {
            let effectiveOpacity = min(activeConfig.transparency, theme.surfaceTokens.surfaceOpacity)
            VisualEffectBlur(material: .headerView, blendingMode: .withinWindow)
                .background(theme.surfaceContainerLow.opacity(effectiveOpacity))
        } else {
            theme.surfaceContainerLow
        }
    }

    // MARK: - Mac Notch & Dynamic Island Adaptive Top Bar Layout (Requirement 3)

    private func computeNotchForSolver(totalLength: CGFloat, islandExclusion: Double) -> ScreenNotchGeometry {
        if effectiveNotch.hasNotch {
            return effectiveNotch
        } else if islandExclusion > 0 {
            return ScreenNotchGeometry.fromScreenMeasurements(
                screenID: "island",
                screenWidth: Double(totalLength) + Double(activeConfig.margin * 2),
                screenHeight: effectiveNotch.screenHeight,
                safeAreaTop: Double(activeConfig.thickness),
                auxiliaryLeftWidth: nil,
                auxiliaryRightMinX: nil,
                auxiliaryRightWidth: nil,
                simulateNotch: true,
                simulatedNotchWidth: islandExclusion,
                simulatedNotchHeight: Double(activeConfig.thickness)
            )
        } else {
            return effectiveNotch
        }
    }

    @ViewBuilder
    private func notchedHorizontalBarContent(totalLength: CGFloat) -> some View {
        let screen = (screenIndex < NSScreen.screens.count) ? NSScreen.screens[screenIndex] : (NSScreen.main ?? NSScreen.screens.first)
        let islandExclusion: Double = screen.map { Double(island.exclusionWidth(for: $0, barPosition: activeConfig.position)) } ?? 0.0
        let notchForSolver = computeNotchForSolver(totalLength: totalLength, islandExclusion: islandExclusion)

        let solved = NotchAwareBarLayoutSolver.solve(
            layout: activeConfig.layout,
            notch: notchForSolver,
            barMargin: Double(activeConfig.margin),
            spacing: Double(activeConfig.spacing),
            islandExclusionWidth: islandExclusion
        )

        let leftSafeWidth = max(60, CGFloat(solved.leftSafeEndX))
        let rightSafeWidth = max(60, totalLength - CGFloat(solved.rightSafeStartX))
        let centerHoleWidth = max(0, CGFloat(solved.rightSafeStartX - solved.leftSafeEndX))
        let hPad = CGFloat(activeConfig.horizontalPadding)
        let vPad = CGFloat(activeConfig.verticalPadding)

        let leftShape = barContainerShape(isLeftWing: true)
        let rightShape = barContainerShape(isRightWing: true)

        HStack(spacing: 0) {
            // Left Safe Zone Wing (Left of Notch / Dynamic Island)
            HStack(spacing: 4) {
                let leftRoles = BarSegmentRoleSolver.resolve(
                    entries: solved.leftSafeWidgets,
                    participating: solved.leftSafeWidgets.map { $0.enabled }
                )
                renderWidgets(entries: solved.leftSafeWidgets, roles: leftRoles)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .frame(width: leftSafeWidth)
            .frame(maxHeight: .infinity)
            .background(barBackground)
            .clipShape(leftShape)
            .overlay(
                Group {
                    if activeConfig.borderEnabled && activeConfig.backgroundStyle.lowercased() != "island" {
                        leftShape.stroke(resolvedBorderColor, lineWidth: CGFloat(max(0.0, activeConfig.borderWidth)))
                    }
                }
            )
            .clipped()

            // Central Exclusion Zone for Hardware Notch & Dynamic Island
            Spacer(minLength: centerHoleWidth)
                .frame(width: centerHoleWidth)

            // Right Safe Zone Wing (Right of Notch / Dynamic Island)
            HStack(spacing: 4) {
                Spacer(minLength: 0)
                let rightRoles = BarSegmentRoleSolver.resolve(
                    entries: solved.rightSafeWidgets,
                    participating: solved.rightSafeWidgets.map { $0.enabled }
                )
                renderWidgets(entries: solved.rightSafeWidgets, roles: rightRoles)
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .frame(width: rightSafeWidth)
            .frame(maxHeight: .infinity)
            .background(barBackground)
            .clipShape(rightShape)
            .overlay(
                Group {
                    if activeConfig.borderEnabled && activeConfig.backgroundStyle.lowercased() != "island" {
                        rightShape.stroke(resolvedBorderColor, lineWidth: CGFloat(max(0.0, activeConfig.borderWidth)))
                    }
                }
            )
            .clipped()
        }
    }

    // MARK: - Standard Horizontal Layout
    @ViewBuilder
    private func horizontalBarContent(totalLength: CGFloat) -> some View {
        let hPad = CGFloat(activeConfig.horizontalPadding)
        let vPad = CGFloat(activeConfig.verticalPadding)

        HStack(spacing: CGFloat(activeConfig.spacing)) {
            // Left Section
            leftWidgetsRow
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: LeftSizePreferenceKey.self, value: geo.size.width)
                    }
                )

            Spacer(minLength: 16)

            // Right Section
            rightWidgetsRow
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: RightSizePreferenceKey.self, value: geo.size.width)
                    }
                )
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPreferenceChange(LeftSizePreferenceKey.self) { newValue in
            if abs(leftSectionSize - newValue) > 0.5 {
                leftSectionSize = newValue
            }
        }
        .onPreferenceChange(RightSizePreferenceKey.self) { newValue in
            if abs(rightSectionSize - newValue) > 0.5 {
                rightSectionSize = newValue
            }
        }
        .overlay(
            // True Geometric Center Layout with Collision Confinement
            GeometryReader { overlayGeo in
                let bounds = BarCenterLayoutSolver.Bounds(
                    min: Double(leftSectionSize + hPad + 8),
                    max: Double(totalLength - rightSectionSize - hPad - 8)
                )
                let solverResult = BarCenterLayoutSolver.resolve(
                    sizes: [Double(centerSectionSize)],
                    length: Double(totalLength),
                    spacing: Double(activeConfig.spacing),
                    mode: "geometric",
                    bounds: bounds
                )
                let solvedStart = CGFloat(solverResult.positions.first.flatMap { $0 } ?? 0)

                centerWidgetsRow
                    .background(
                        GeometryReader { sizeGeo in
                            Color.clear.preference(key: CenterSizePreferenceKey.self, value: sizeGeo.size.width)
                        }
                    )
                    .position(x: solvedStart + centerSectionSize / 2.0, y: overlayGeo.size.height / 2.0)
            }
        )
        .onPreferenceChange(CenterSizePreferenceKey.self) { newValue in
            if abs(centerSectionSize - newValue) > 0.5 {
                centerSectionSize = newValue
            }
        }
    }

    // MARK: - Vertical Layout
    @ViewBuilder
    private func verticalBarContent(totalLength: CGFloat) -> some View {
        let vPad = CGFloat(activeConfig.horizontalPadding)

        VStack(spacing: CGFloat(activeConfig.spacing)) {
            // Top Section (corresponding to Left)
            leftWidgetsRow
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: LeftSizePreferenceKey.self, value: geo.size.height)
                    }
                )

            Spacer(minLength: 16)

            // Bottom Section (corresponding to Right)
            rightWidgetsRow
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: RightSizePreferenceKey.self, value: geo.size.height)
                    }
                )
        }
        .padding(.vertical, vPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPreferenceChange(LeftSizePreferenceKey.self) { newValue in
            if abs(leftSectionSize - newValue) > 0.5 {
                leftSectionSize = newValue
            }
        }
        .onPreferenceChange(RightSizePreferenceKey.self) { newValue in
            if abs(rightSectionSize - newValue) > 0.5 {
                rightSectionSize = newValue
            }
        }
        .overlay(
            GeometryReader { overlayGeo in
                let bounds = BarCenterLayoutSolver.Bounds(
                    min: Double(leftSectionSize + vPad + 8),
                    max: Double(totalLength - rightSectionSize - vPad - 8)
                )
                let solverResult = BarCenterLayoutSolver.resolve(
                    sizes: [Double(centerSectionSize)],
                    length: Double(totalLength),
                    spacing: Double(activeConfig.spacing),
                    mode: "geometric",
                    bounds: bounds
                )
                let solvedStart = CGFloat(solverResult.positions.first.flatMap { $0 } ?? 0)

                centerWidgetsRow
                    .background(
                        GeometryReader { sizeGeo in
                            Color.clear.preference(key: CenterSizePreferenceKey.self, value: sizeGeo.size.height)
                        }
                    )
                    .position(x: overlayGeo.size.width / 2.0, y: solvedStart + centerSectionSize / 2.0)
            }
        )
        .onPreferenceChange(CenterSizePreferenceKey.self) { newValue in
            if abs(centerSectionSize - newValue) > 0.5 {
                centerSectionSize = newValue
            }
        }
    }

    // MARK: - Left / Top Widgets Row
    @ViewBuilder
    private var leftWidgetsRow: some View {
        let entries = activeConfig.layout.left
        let roles = BarSegmentRoleSolver.resolve(entries: entries, participating: entries.map { $0.enabled })

        if isVertical {
            VStack(spacing: 2) {
                renderWidgets(entries: entries, roles: roles)
            }
        } else {
            HStack(spacing: 2) {
                renderWidgets(entries: entries, roles: roles)
            }
        }
    }

    // MARK: - Center Widgets Row
    @ViewBuilder
    private var centerWidgetsRow: some View {
        let entries = activeConfig.layout.center
        let roles = BarSegmentRoleSolver.resolve(entries: entries, participating: entries.map { $0.enabled })

        Group {
            if isVertical {
                VStack(spacing: 2) {
                    renderWidgets(entries: entries, roles: roles)
                }
            } else {
                HStack(spacing: 4) {
                    renderWidgets(entries: entries, roles: roles)
                }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let frameInWindow = geo.frame(in: .global)
                        let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == NSScreen.main }) ?? DankBarController.shared.panel
                        DashController.shared.reportCenterRowFrame(frameInWindow, in: barPanel)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == NSScreen.main }) ?? DankBarController.shared.panel
                        DashController.shared.reportCenterRowFrame(newFrame, in: barPanel)
                    }
            }
        )
    }

    // MARK: - Right / Bottom Widgets Row
    @ViewBuilder
    private var rightWidgetsRow: some View {
        let entries = activeConfig.layout.right
        let roles = BarSegmentRoleSolver.resolve(entries: entries, participating: entries.map { $0.enabled })

        if isVertical {
            VStack(spacing: 2) {
                renderWidgets(entries: entries, roles: roles)
            }
        } else {
            HStack(spacing: 2) {
                renderWidgets(entries: entries, roles: roles)
            }
        }
    }

    // MARK: - Widget Dispatcher
    @ViewBuilder
    private func renderWidgets(entries: [BarWidgetEntry], roles: [SegmentRole]) -> some View {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            if entry.enabled {
                let role = index < roles.count ? roles[index] : .solo
                let style = entry.styleOptions
                let pillRadius = style.cornerRadiusOverride.map { CGFloat($0) } ?? 14.0
                renderWidget(id: entry.widgetId, options: entry.options, style: style)
                    .segmentedPill(role: role, isVertical: isVertical, radius: pillRadius)
            }
        }
    }

    @ViewBuilder
    private func renderWidget(id: String, options: [String: AnyCodable], style: BarWidgetStyleOptions) -> some View {
        switch id {
        case "launcherButton":
            launcherButton(style: style)
        case "workspaceSwitcher":
            workspaceSwitcher
        case "runningApps", "workspaceApps":
            runningAppsWidget
        case "focusedApp":
            if configStore.config.showWorkspaceApps && !activeConfig.layout.left.contains(where: { $0.widgetId == "runningApps" || $0.widgetId == "workspaceApps" }) {
                runningAppsWidget
            } else {
                focusedAppPill(style: style)
            }
        case "clock":
            BarClockWidgetView(isVertical: isVertical, options: options, style: style)
        case "media", "mediaControls":
            mediaWidget(style: style)
        case "mediaLyricLine":
            mediaLyricWidget(style: style)
        case "audioVisualization":
            AudioVisualizerWidget(isVertical: isVertical)
        case "cpuMonitor":
            CpuMonitorWidget(isVertical: isVertical)
        case "ramMonitor", "ram", "memory":
            RamMonitorWidget(isVertical: isVertical)
        case "cpuTemperature":
            CpuTemperatureWidget(isVertical: isVertical, options: options, style: style)
        case "gpuTemperature":
            GpuTemperatureWidget(isVertical: isVertical, options: options, style: style)
        case "gpuMonitor", "gpu":
            GpuMonitorWidget(isVertical: isVertical)
        case "diskUsage":
            DiskGaugeWidget(isVertical: isVertical)
        case "networkMonitor":
            NetworkMonitorWidget(isVertical: isVertical, options: options, style: style)
        case "capsLockIndicator":
            CapsLockIndicatorWidget(isVertical: isVertical)
        case "keyboardLayoutName":
            KeyboardLayoutWidget(isVertical: isVertical, options: options, style: style)
        case "telemetry", "monitorPill":
            telemetryPill(style: style)
        case "weather":
            weatherPill(style: style)
        case "battery":
            batteryPill(style: style)
        case "inhibit", "idleInhibitor":
            inhibitPill(style: style)
        case "mic":
            micPill(style: style)
        case "wifi":
            wifiPill(style: style)
        case "vpn":
            vpnPill(style: style)
        case "systemUpdate":
            systemUpdatePill(style: style)
        case "systemTray":
            systemTrayPill(style: style)
        case "volume", "audio":
            volumePill(style: style)
        case "notificationCenterButton":
            notificationCenterButton(style: style)
        case "controlCenterButton":
            controlCenterButton(style: style)
        case "powerMenuButton":
            powerMenuButton(style: style)
        case "notepadButton", "notepadApplet":
            notepadButton(style: style)
        case "clipboardButton", "clipboardApplet":
            clipboardButton(style: style)
        case "colorPicker", "colorPickerApplet":
            colorPickerButton(style: style)
        case "spacer":
            Spacer(minLength: CGFloat(options["width"]?.doubleValue ?? 12.0))
                .frame(width: isVertical ? nil : CGFloat(options["width"]?.doubleValue ?? 12.0),
                       height: isVertical ? CGFloat(options["width"]?.doubleValue ?? 12.0) : nil)
        case "separator":
            Rectangle()
                .fill(theme.outlineVariant.opacity(0.45))
                .frame(width: isVertical ? 16 : 1, height: isVertical ? 1 : 16)
                .padding(isVertical ? .vertical : .horizontal, 4)
        default:
            EmptyView()
        }
    }

    // MARK: - Style Override Helpers

    private func resolveWidgetBackground(_ style: BarWidgetStyleOptions, defaultColor: Color) -> Color {
        if let hex = style.customBackgroundHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return defaultColor
    }

    private func resolveWidgetTint(_ style: BarWidgetStyleOptions, defaultColor: Color) -> Color {
        if let hex = style.customTintHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return defaultColor
    }

    // MARK: - Concrete Widget Views

    private func launcherButton(style: BarWidgetStyleOptions) -> some View {
        let hPad = style.paddingOverride.map { CGFloat($0) } ?? (style.compactMode ? 8 : 11)
        return Button {
            LauncherController.shared.toggle()
        } label: {
            HStack(spacing: 5) {
                if style.showIcon {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(resolveWidgetTint(style, defaultColor: theme.onPrimary))
                }
                if !isVertical && style.showLabel && !style.compactMode {
                    Text("DMS")
                        .font(theme.font(size: 11, weight: .bold))
                        .foregroundColor(resolveWidgetTint(style, defaultColor: theme.onPrimary))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, isVertical ? 0 : hPad)
            .frame(width: isVertical ? 28 : nil, height: 28)
            .background(resolveWidgetBackground(style, defaultColor: theme.primary))
        }
        .buttonStyle(.plain)
    }

    private var workspaceSwitcher: some View {
        let workspaceItems: [WorkspaceInfo] = workspace.workspaces.isEmpty
            ? (1...max(4, workspace.spacesCount)).map { WorkspaceInfo(id: "\($0)", number: $0, name: "\($0)", isCurrent: workspace.activeSpaceIndex == $0) }
            : workspace.workspaces

        return Group {
            if isVertical {
                VStack(spacing: 3) {
                    ForEach(workspaceItems) { ws in
                        workspaceButton(ws: ws)
                    }
                }
                .padding(.vertical, 4)
                .frame(width: 28)
                .background(theme.surfaceContainerHigh)
            } else {
                HStack(spacing: 3) {
                    ForEach(workspaceItems) { ws in
                        workspaceButton(ws: ws)
                    }
                }
                .padding(.horizontal, 5)
                .frame(height: 28)
                .background(theme.surfaceContainerHigh)
            }
        }
    }

    @ViewBuilder
    private func workspaceButton(ws: WorkspaceInfo) -> some View {
        let isSelected = ws.isCurrent || workspace.activeSpaceIndex == ws.number
        Button(action: {
            workspace.switchSpace(ws.number)
        }) {
            Text(ws.name)
                .font(theme.font(size: 11, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? theme.onPrimary : theme.onSurface)
                .frame(minWidth: 20, minHeight: 20)
                .padding(.horizontal, (!isVertical && ws.name.count > 1) ? 4 : 0)
                .padding(.vertical, (isVertical && ws.name.count > 1) ? 2 : 0)
                .background(isSelected ? theme.primary : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var runningAppsWidget: some View {
        if !workspace.currentWorkspaceApps.isEmpty {
            if isVertical {
                VStack(spacing: 4) {
                    ForEach(workspace.currentWorkspaceApps) { app in
                        WorkspaceAppItemView(app: app, isVertical: isVertical)
                    }
                }
                .padding(.vertical, 4)
                .frame(width: 28)
                .background(theme.surfaceContainerHigh.opacity(0.8))
            } else {
                HStack(spacing: 4) {
                    ForEach(workspace.currentWorkspaceApps) { app in
                        WorkspaceAppItemView(app: app, isVertical: isVertical)
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 28)
                .background(theme.surfaceContainerHigh.opacity(0.8))
            }
        }
    }

    private func focusedAppPill(style: BarWidgetStyleOptions) -> some View {
        Group {
            if let front = NSWorkspace.shared.frontmostApplication,
               let name = front.localizedName {
                HStack(spacing: 5) {
                    if style.showIcon {
                        Image(nsImage: front.icon ?? NSImage())
                            .resizable()
                            .frame(width: 14, height: 14)
                    }
                    if !isVertical && style.showLabel && !style.compactMode {
                        Text(name)
                            .font(theme.font(size: 11, weight: .medium))
                            .foregroundColor(resolveWidgetTint(style, defaultColor: theme.onSurface))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, isVertical ? 0 : (style.paddingOverride.map { CGFloat($0) } ?? 7))
                .frame(width: isVertical ? 28 : nil, height: 28)
                .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh.opacity(0.8)))
            }
        }
    }

    private func mediaWidget(style: BarWidgetStyleOptions) -> some View {
        Group {
            let track = nowPlaying.currentTrack
            let hasActiveTrack = track.isPlaying || (!track.title.isEmpty && track.title != "No Track Playing")
            if hasActiveTrack {
                Button(action: { nowPlaying.playPause() }) {
                    HStack(spacing: 5) {
                        if style.showIcon {
                            Image(systemName: track.isPlaying ? "music.note" : "pause.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(resolveWidgetTint(style, defaultColor: theme.primary))
                        }
                        if !isVertical && style.showLabel && !style.compactMode {
                            Text(track.title)
                                .font(theme.font(size: 11, weight: .medium))
                                .foregroundColor( theme.onSurface)
                                .lineLimit(1)
                                .frame(maxWidth: 160)
                        }
                    }
                    .padding(.horizontal, isVertical ? 0 : (style.paddingOverride.map { CGFloat($0) } ?? 8))
                    .frame(width: isVertical ? 28 : nil, height: 28)
                    .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
                }
                .buttonStyle(.plain)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                let frameInWindow = geo.frame(in: .global)
                                let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == NSScreen.main }) ?? DankBarController.shared.panel
                                DashController.shared.reportMediaFrame(frameInWindow, in: barPanel)
                            }
                            .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == NSScreen.main }) ?? DankBarController.shared.panel
                                DashController.shared.reportMediaFrame(newFrame, in: barPanel)
                            }
                            .onDisappear {
                                DashController.shared.reportMediaFrame(nil, in: nil)
                            }
                    }
                )
            }
        }
    }

    private func mediaLyricWidget(style: BarWidgetStyleOptions) -> some View {
        let track = nowPlaying.currentTrack
        let lyricText = track.artist.isEmpty ? track.title : "\(track.title) — \(track.artist)"
        return Group {
            if !track.title.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 10))
                        .foregroundColor(resolveWidgetTint(style, defaultColor: theme.primary))
                    if !isVertical {
                        Text(lyricText)
                            .font(theme.font(size: 11, weight: .medium))
                            .foregroundColor(theme.onSurfaceVariant)
                            .lineLimit(1)
                            .frame(maxWidth: 180)
                    }
                }
                .padding(.horizontal, isVertical ? 0 : 8)
                .frame(width: isVertical ? 28 : nil, height: 28)
                .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
            }
        }
    }

    private func networkMonitorPill(style: BarWidgetStyleOptions) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.arrow.down.circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(resolveWidgetTint(style, defaultColor: theme.primary))
            if !isVertical && style.showLabel && !style.compactMode {
                Text(wifi.isConnected ? "Online" : "Offline")
                    .font(theme.font(size: 10, weight: .semibold, mono: true))
                    .foregroundColor(theme.onSurface)
            }
        }
        .padding(.horizontal, isVertical ? 0 : 8)
        .frame(width: isVertical ? 28 : nil, height: 28)
        .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
    }

    private func keyboardLayoutPill(style: BarWidgetStyleOptions) -> some View {
        let layoutName = Self.currentKeyboardLayoutCode()
        return HStack(spacing: 4) {
            if style.showIcon {
                Image(systemName: "keyboard")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(resolveWidgetTint(style, defaultColor: theme.primary))
            }
            if !isVertical && style.showLabel {
                Text(layoutName)
                    .font(theme.font(size: 10, weight: .bold, mono: true))
                    .foregroundColor(theme.onSurface)
            }
        }
        .padding(.horizontal, isVertical ? 0 : 7)
        .frame(width: isVertical ? 28 : nil, height: 28)
        .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
    }

    private static func currentKeyboardLayoutCode() -> String {
        if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
           let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
            let name = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
            return String(name.prefix(3)).uppercased()
        }
        return "US"
    }

    private func weatherPill(style: BarWidgetStyleOptions) -> some View {
        let hPad = style.paddingOverride.map { CGFloat($0) } ?? (style.compactMode ? 8 : 11)
        return Button(action: { DashController.shared.toggle(tab: .weather) }) {
            HStack(spacing: 5) {
                if style.showIcon {
                    Image(systemName: weather.currentWeather.sfSymbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(resolveWidgetTint(style, defaultColor: theme.primary))
                }
                if !isVertical && style.showLabel && !style.compactMode {
                    let isCelsius = configStore.config.weatherUnits.lowercased() == "celsius"
                    let temp = isCelsius ? weather.currentWeather.temperatureC : weather.currentWeather.temperatureF
                    Text("\(Int(round(temp)))°")
                        .font(theme.font(size: 11, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, isVertical ? 0 : hPad)
            .frame(width: isVertical ? 28 : nil, height: 28)
            .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
    }

    private func telemetryPill(style: BarWidgetStyleOptions) -> some View {
        Button {
            ProcessListController.shared.toggle(sortByMemory: false, anchorX: NSEvent.mouseLocation.x)
        } label: {
            HStack(spacing: 4) {
                if style.showIcon {
                    Image(systemName: "cpu")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(resolveWidgetTint(style, defaultColor: theme.primary))
                }
                if !isVertical && style.showLabel && !style.compactMode {
                    Text("\(Int(telemetry.telemetry.cpuPercent))%")
                        .font(theme.font(size: 11, weight: .semibold, mono: true))
                        .foregroundColor(theme.onSurface)
                }
            }
            .padding(.horizontal, isVertical ? 0 : (style.paddingOverride.map { CGFloat($0) } ?? 8))
            .frame(width: isVertical ? 28 : nil, height: 28)
            .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
    }

    private func batteryPill(style: BarWidgetStyleOptions) -> some View {
        Group {
            if let bat = battery.status {
                Button {
                    BatteryPopoutController.shared.toggle(anchorX: NSEvent.mouseLocation.x)
                } label: {
                    HStack(spacing: 4) {
                        if style.showIcon {
                            Image(systemName: bat.isCharging ? "battery.100.bolt" : "battery.75")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(bat.isCharging ? theme.success : resolveWidgetTint(style, defaultColor: theme.onSurface))
                        }
                        if !isVertical && style.showLabel && !style.compactMode {
                            Text("\(bat.capacity)%")
                                .font(theme.font(size: 11, weight: .semibold, mono: true))
                                .foregroundColor(theme.onSurface)
                        }
                    }
                    .padding(.horizontal, isVertical ? 0 : (style.paddingOverride.map { CGFloat($0) } ?? 8))
                    .frame(width: isVertical ? 28 : nil, height: 28)
                    .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func inhibitPill(style: BarWidgetStyleOptions) -> some View {
        Button(action: { DurationPopoutController.shared.toggle(anchorX: NSEvent.mouseLocation.x) }) {
            HStack(spacing: 3) {
                Image(systemName: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(inhibit.isInhibited ? theme.onPrimary : resolveWidgetTint(style, defaultColor: theme.onSurface))

                if !isVertical && style.showLabel && inhibit.isInhibited,
                   let remaining = inhibit.formattedRemainingTimeShort {
                    Text(remaining)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.onPrimary)
                }
            }
            .padding(.horizontal, isVertical ? 0 : (inhibit.isInhibited && !isVertical && style.showLabel ? 6 : 0))
            .frame(width: isVertical ? 28 : (inhibit.isInhibited && !isVertical && style.showLabel ? nil : 28), height: 28)
            .background(inhibit.isInhibited ? theme.primary : resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(inhibit.isInhibited ? "Disable Sleep Inhibit" : "Keep Awake (Indefinite)") {
                inhibit.toggle()
            }
            Divider()
            ForEach(IdleInhibitPreset.allCases) { preset in
                Button(preset.label) {
                    inhibit.enable(preset: preset)
                }
            }
        }
        .help(inhibit.isInhibited ? "Sleep Inhibit: Active (\(inhibit.formattedRemainingTime ?? "Indefinite"))" : "Sleep Inhibit: Disabled (Click for presets)")
    }

    private func micPill(style: BarWidgetStyleOptions) -> some View {
        Button(action: { audio.toggleMicMute() }) {
            Image(systemName: audio.isMicMuted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(audio.isMicMuted ? theme.error : resolveWidgetTint(style, defaultColor: theme.primary))
                .frame(width: 28, height: 28)
                .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
    }

    private func wifiPill(style: BarWidgetStyleOptions) -> some View {
        HStack(spacing: 0) {
            Image(systemName: wifi.symbolName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(wifi.isConnected ? resolveWidgetTint(style, defaultColor: theme.primary) : theme.outline)
        }
        .frame(width: 28, height: 28)
        .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
    }

    private func vpnPill(style: BarWidgetStyleOptions) -> some View {
        HStack(spacing: 0) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(resolveWidgetTint(style, defaultColor: theme.primary))
        }
        .frame(width: 28, height: 28)
        .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
    }

    private func systemUpdatePill(style: BarWidgetStyleOptions) -> some View {
        Button {
            SettingsController.shared.show()
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(resolveWidgetTint(style, defaultColor: theme.onSurface))
                .frame(width: 28, height: 28)
                .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
    }

    private func systemTrayPill(style: BarWidgetStyleOptions) -> some View {
        Button {
            DIslandController.shared.toggle(activity: .home)
        } label: {
            Image(systemName: "MenuBarRectangle")
                .symbolVariant(.fill)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(resolveWidgetTint(style, defaultColor: theme.primary))
                .frame(width: 28, height: 28)
                .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
    }

    private func volumePill(style: BarWidgetStyleOptions) -> some View {
        Button {
            AudioPopoutController.shared.toggle(anchorX: NSEvent.mouseLocation.x)
        } label: {
            HStack(spacing: 0) {
                Image(systemName: audio.currentOutputIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(audio.isMuted ? theme.outline : resolveWidgetTint(style, defaultColor: theme.primary))
            }
            .frame(width: 28, height: 28)
            .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
        .help("Audio Output: \(audio.currentOutputName) (\(Int(audio.volume * 100))%)")
    }

    private func notificationCenterButton(style: BarWidgetStyleOptions) -> some View {
        Button {
            DIslandController.shared.toggle(activity: .notification)
        } label: {
            Image(systemName: "bell.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(resolveWidgetTint(style, defaultColor: theme.onSurface))
                .frame(width: 28, height: 28)
                .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
    }

    private func controlCenterButton(style: BarWidgetStyleOptions) -> some View {
        Button {
            ControlCenterController.shared.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ControlCenterController.shared.isVisible ? theme.onPrimary : resolveWidgetTint(style, defaultColor: theme.onSurface))
                .frame(width: 28, height: 28)
                .background(ControlCenterController.shared.isVisible ? theme.primary : resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
    }

    private func powerMenuButton(style: BarWidgetStyleOptions) -> some View {
        Button {
            PowerPopoutController.shared.toggle(anchorX: NSEvent.mouseLocation.x)
        } label: {
            Image(systemName: "power")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(resolveWidgetTint(style, defaultColor: theme.onSurface))
                .frame(width: 28, height: 28)
                .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
        .help("Power & Session")
    }

    private func notepadButton(style: BarWidgetStyleOptions) -> some View {
        Button(action: { NotepadController.shared.toggle() }) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(resolveWidgetTint(style, defaultColor: theme.onSurface))
                .frame(width: 28, height: 28)
                .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
    }

    private func clipboardButton(style: BarWidgetStyleOptions) -> some View {
        Button(action: { ClipboardController.shared.toggle() }) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(resolveWidgetTint(style, defaultColor: theme.onSurface))
                .frame(width: 28, height: 28)
                .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
    }

    private func colorPickerButton(style: BarWidgetStyleOptions) -> some View {
        Button(action: { ColorPickerPopoutController.shared.toggle(anchorX: NSEvent.mouseLocation.x) }) {
            Image(systemName: "eyedropper")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(resolveWidgetTint(style, defaultColor: theme.onSurface))
                .frame(width: 28, height: 28)
                .background(resolveWidgetBackground(style, defaultColor: theme.surfaceContainerHigh))
        }
        .buttonStyle(.plain)
        .help("Color Picker")
    }
}

// MARK: - Isolated Clock Widget View (Eliminates 1Hz Full-Bar Re-Renders)

private struct BarClockWidgetView: View {
    let isVertical: Bool
    let options: [String: AnyCodable]
    let style: BarWidgetStyleOptions

    @ObservedObject private var theme = ThemeStore.shared
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let time12Formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
    private static let time12SecFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm:ss a"
        return f
    }()
    private static let time24Formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let time24SecFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()
    private static let hour12Formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h"
        return f
    }()
    private static let hour24Formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH"
        return f
    }()
    private static let minFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "mm"
        return f
    }()

    var body: some View {
        let showDate = (options["showDate"]?.boolValue ?? true) && !style.compactMode
        let timeFormat = options["timeFormat"]?.stringValue ?? "12h"
        let showSeconds = options["showSeconds"]?.boolValue ?? false

        let formatter: DateFormatter = {
            if timeFormat == "24h" {
                return showSeconds ? Self.time24SecFormatter : Self.time24Formatter
            } else {
                return showSeconds ? Self.time12SecFormatter : Self.time12Formatter
            }
        }()
        let hourFormatter = (timeFormat == "24h") ? Self.hour24Formatter : Self.hour12Formatter

        Button(action: { DashController.shared.toggle() }) {
            if isVertical {
                VStack(spacing: 1) {
                    Text(hourFormatter.string(from: currentTime))
                        .font(theme.font(size: 11, weight: .bold, mono: true))
                        .foregroundColor(theme.onSurface)
                    Text(Self.minFormatter.string(from: currentTime))
                        .font(theme.font(size: 11, weight: .semibold, mono: true))
                        .foregroundColor(theme.primary)
                }
                .frame(width: 28, height: 38)
                .background(style.customBackgroundHex.map { Color(hex: $0) } ?? theme.surfaceContainerHigh)
            } else {
                HStack(spacing: 5) {
                    if style.showIcon {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(style.customTintHex.map { Color(hex: $0) } ?? theme.primary)
                    }
                    if style.showLabel {
                        Text(formatter.string(from: currentTime))
                            .font(theme.font(size: 12, weight: .semibold, mono: true))
                            .foregroundColor(theme.onSurface)
                            .lineLimit(1)
                        if showDate {
                            Text("•")
                                .foregroundColor(theme.outlineVariant)
                            Text(Self.dateFormatter.string(from: currentTime))
                                .font(theme.font(size: 11, weight: .medium))
                                .foregroundColor(theme.onSurfaceVariant)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, style.paddingOverride.map { CGFloat($0) } ?? 10)
                .frame(height: 28)
                .background(style.customBackgroundHex.map { Color(hex: $0) } ?? theme.surfaceContainerHigh)
            }
        }
        .buttonStyle(.plain)
        .onReceive(timer) { now in
            currentTime = now
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let frameInWindow = geo.frame(in: .global)
                        let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == NSScreen.main }) ?? DankBarController.shared.panel
                        DashController.shared.reportClockFrame(frameInWindow, in: barPanel)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        let barPanel = DankBarController.shared.panels.values.first(where: { $0.screen == NSScreen.main }) ?? DankBarController.shared.panel
                        DashController.shared.reportClockFrame(newFrame, in: barPanel)
                    }
            }
        )
    }
}

// MARK: - Preference Keys for Dynamic Geometric Size Tracking
private struct LeftSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 200
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct RightSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 300
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CenterSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 180
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Represents an interactive application pill open in the current workspace.
public struct WorkspaceAppItemView: View {
    public let app: WorkspaceAppItem
    public var isVertical: Bool
    @ObservedObject private var theme = ThemeStore.shared

    public init(app: WorkspaceAppItem, isVertical: Bool = false) {
        self.app = app
        self.isVertical = isVertical
    }

    public var body: some View {
        Button {
            WorkspaceService.shared.activate(app: app)
        } label: {
            Group {
                if app.isActive {
                    if isVertical {
                        appIcon(size: 14)
                            .frame(width: 22, height: 22)
                            .background(theme.primaryContainer.opacity(0.7))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(theme.primary.opacity(0.6), lineWidth: 1)
                            )
                    } else {
                        HStack(spacing: 5) {
                            appIcon(size: 14)
                            Text(app.name)
                                .font(theme.font(size: 11, weight: .semibold))
                                .foregroundColor(theme.onSurface)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(theme.primaryContainer.opacity(0.7))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(theme.primary.opacity(0.4), lineWidth: 1)
                        )
                    }
                } else {
                    appIcon(size: 14)
                        .frame(width: 22, height: 22)
                        .background(theme.surfaceContainerLow)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(theme.outlineVariant.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .help(app.name)
    }

    @ViewBuilder
    private func appIcon(size: CGFloat) -> some View {
        if !app.path.isEmpty && FileManager.default.fileExists(atPath: app.path) {
            AppIconImage(path: app.path, size: size)
        } else if let icon = NSWorkspace.shared.runningApplications.first(where: {
            (!app.bundleID.isEmpty && $0.bundleIdentifier == app.bundleID) || (app.pid != 0 && $0.processIdentifier == app.pid)
        })?.icon {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            AppIconImage(path: app.path, size: size)
        }
    }
}
