import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DMSCore

// MARK: - Goth Corner Shape (Spec 19 / Spec 24 Concave Top Fillets)

/// Draws an island or bar container with optional concave top-left/top-right fillets ("Goth corners")
/// that blend seamlessly into the top screen edge or Mac hardware notch.
public struct GothCornerShape: Shape {
    public var rTL: CGFloat
    public var rTR: CGFloat
    public var rBR: CGFloat
    public var rBL: CGFloat
    public var concaveTopFillets: Bool
    public var filletRadius: CGFloat

    public init(
        rTL: CGFloat = 18,
        rTR: CGFloat = 18,
        rBR: CGFloat = 18,
        rBL: CGFloat = 18,
        concaveTopFillets: Bool = false,
        filletRadius: CGFloat = 12
    ) {
        self.rTL = rTL
        self.rTR = rTR
        self.rBR = rBR
        self.rBL = rBL
        self.concaveTopFillets = concaveTopFillets
        self.filletRadius = filletRadius
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 && rect.height > 0 else { return path }

        if concaveTopFillets {
            let f = min(filletRadius, rect.width * 0.25, rect.height * 0.5)
            let br = min(rBR, (rect.width - 2 * f) * 0.5, rect.height * 0.5)
            let bl = min(rBL, (rect.width - 2 * f) * 0.5, rect.height * 0.5)

            // Start at top-left outer flange
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            // Top edge across to top-right outer flange
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            // Concave circular fillet curving inward-downward on right
            path.addArc(
                center: CGPoint(x: rect.maxX, y: rect.minY + f),
                radius: f,
                startAngle: .degrees(270),
                endAngle: .degrees(180),
                clockwise: true
            )
            // Right vertical edge down to bottom-right corner
            path.addLine(to: CGPoint(x: rect.maxX - f, y: rect.maxY - br))
            path.addArc(
                center: CGPoint(x: rect.maxX - f - br, y: rect.maxY - br),
                radius: br,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            // Bottom edge across to bottom-left corner
            path.addLine(to: CGPoint(x: rect.minX + f + bl, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + f + bl, y: rect.maxY - bl),
                radius: bl,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            // Left vertical edge up to top-left concave fillet
            path.addLine(to: CGPoint(x: rect.minX + f, y: rect.minY + f))
            path.addArc(
                center: CGPoint(x: rect.minX, y: rect.minY + f),
                radius: f,
                startAngle: .degrees(0),
                endAngle: .degrees(270),
                clockwise: true
            )
            path.closeSubpath()
            return path
        } else {
            let tl = min(rTL, rect.width * 0.5, rect.height * 0.5)
            let tr = min(rTR, rect.width * 0.5, rect.height * 0.5)
            let br = min(rBR, rect.width * 0.5, rect.height * 0.5)
            let bl = min(rBL, rect.width * 0.5, rect.height * 0.5)

            path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                radius: tr,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
            path.addArc(
                center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                radius: br,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                radius: bl,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
            path.addArc(
                center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                radius: tl,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
            path.closeSubpath()
            return path
        }
    }
}

// MARK: - Dynamic Island View

public struct DIslandView: View {
    @ObservedObject public var controller: DIslandController
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared

    public init(controller: DIslandController) {
        self.controller = controller
    }

    private var settings: IslandSettings {
        configStore.config.islandSettings
    }

    private var isNotchAttached: Bool {
        !settings.float && (settings.instance == .notch || (settings.instance == .mainBar && (controller.currentNotch.hasNotch || configStore.config.barPosition.lowercased() == "top")))
    }

    private var useGothFillets: Bool {
        settings.gothCorners && (isNotchAttached || (settings.float && settings.edge.lowercased() == "top") || (settings.instance == .mainBar && configStore.config.barPosition.lowercased() == "top") || settings.instance == .notch)
    }

    public var body: some View {
        let geom = controller.currentGeometry
        let shape = GothCornerShape(
            rTL: CGFloat(geom.topLeftRadius),
            rTR: CGFloat(geom.topRightRadius),
            rBR: CGFloat(geom.bottomRightRadius),
            rBL: CGFloat(geom.bottomLeftRadius),
            concaveTopFillets: useGothFillets,
            filletRadius: CGFloat(settings.gothFilletRadius)
        )

        ZStack {
            islandBackground
                .clipShape(shape)
                .overlay(
                    Group {
                        if settings.borderEnabled {
                            shape.stroke(
                                theme.outlineVariant.opacity(theme.surfaceTokens.outlineOpacity * 2.0),
                                lineWidth: CGFloat(max(0.5, theme.surfaceTokens.borderWidth))
                            )
                        }
                    }
                )

            Group {
                if controller.presentationState.isExpanded {
                    switch controller.presentationState {
                    case .expandedControlCenter:
                        ExpandedPanelContainer(controller: controller) {
                            ControlCenterView()
                        }
                    case .expandedDash:
                        ExpandedPanelContainer(controller: controller) {
                            DashView(initialTab: DashController.shared.activeTab, onClose: { controller.close() })
                        }
                    default:
                        ExpandedIslandContent(
                            controller: controller,
                            activity: controller.presentationState.activity,
                            settings: settings,
                            useGothFillets: useGothFillets
                        )
                        .padding(.horizontal, useGothFillets ? 18 : 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                } else {
                    CompactIslandContent(
                        controller: controller,
                        activity: controller.presentationState.activity,
                        isNotchAttached: isNotchAttached,
                        useGothFillets: useGothFillets,
                        settings: settings
                    )
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(shape)
        // DankDrop: dragging files/URLs/text onto the island morphs it into the drop shelf.
        .onDrop(
            of: [.fileURL, .url, .plainText],
            isTargeted: Binding(
                get: { controller.isDropTargeted },
                set: { controller.setDropTargeted($0) }
            )
        ) { providers in
            handleDrop(providers: providers)
        }
        .onHover { hovering in
            controller.setHovered(hovering)
        }
        .onTapGesture {
            if !controller.presentationState.isExpanded {
                controller.toggle()
            }
        }
    }

    /// Accepts dropped file URLs, web URLs, and plain text into the DankDrop shelf.
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            controller.addDroppedFileURL(url)
                        } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            controller.addDroppedFileURL(url)
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            controller.addDroppedFileURL(url)
                        } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            controller.addDroppedFileURL(url)
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    DispatchQueue.main.async {
                        if let text = item as? String {
                            controller.addDroppedText(text)
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }

    @ViewBuilder
    private var islandBackground: some View {
        if settings.opacity <= 0.005 {
            Color.clear
        } else if isNotchAttached && !controller.presentationState.isExpanded {
            Color.black.opacity(max(0.92, settings.opacity))
        } else {
            GlassSurfaceBackground(
                baseColor: theme.isLightMode ? theme.surfaceContainerLowest : theme.surfaceContainerHighest,
                opacity: min(settings.opacity, theme.surfaceTokens.surfaceOpacity),
                forceGlass: settings.opacity < 1.0 || configStore.config.barTransparent,
                material: .popover
            )
        }
    }
}

// MARK: - Compact / Idle State (leaf: observes only what the collapsed island shows)

private struct CompactIslandContent: View {
    @ObservedObject var controller: DIslandController
    let activity: IslandActivity
    let isNotchAttached: Bool
    let useGothFillets: Bool
    let settings: IslandSettings
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var pomodoro = PomodoroService.shared
    private let audio = AudioService.shared

    var body: some View {
        let notchWidth = isNotchAttached ? CGFloat(controller.currentNotch.notchWidth) : 0
        let gothFlange: CGFloat = useGothFillets ? CGFloat(settings.gothFilletRadius) : 0.0
        let totalW = CGFloat(controller.currentGeometry.width) + gothFlange * 2
        let wingWidth = isNotchAttached ? max(84.0, (totalW - notchWidth) / 2.0) : (totalW / 2.0 - 6.0)
        // AudioService is only touched while an OSD is actually active — never in idle/media,
        // so volume polling never keeps the collapsed island re-rendering.
        let payload: (icon: String, label: String, progress: Double?)? =
            activity == .osd ? (controller.osdPayload ?? (icon: audio.currentOutputIcon, label: "Volume", progress: audio.volume)) : nil

        HStack(spacing: 0) {
            // Left Wing (Left of hardware notch)
            HStack(spacing: 5) {
                if activity == .osd, let payload = payload {
                    Image(systemName: payload.icon)
                        .font(ThemeStore.shared.font(size: 11, weight: .bold))
                        .foregroundColor(theme.primary)
                    Text(payload.label)
                        .font(theme.font(size: 11, weight: .semibold))
                        .foregroundColor(isNotchAttached ? .white : theme.onSurface)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                } else if activity == .timer {
                    // Live Pomodoro: phase badge + monospace MM:SS countdown
                    HStack(spacing: 5) {
                        Text(pomodoro.phaseLabel)
                            .font(theme.font(size: 9, weight: .bold))
                            .foregroundColor(isNotchAttached ? .black : theme.onPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(isNotchAttached ? Color.white : theme.primary)
                            .clipShape(Capsule())
                        Text(pomodoro.formattedRemaining)
                            .font(theme.font(size: 11, weight: .bold, mono: true))
                            .foregroundColor(isNotchAttached ? .white : theme.onSurface)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                } else if activity == .fileDrop {
                    // DankDrop: highlighted "Drop to Shelf" pill while targeted, shelf badge otherwise
                    HStack(spacing: 5) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(theme.font(size: 11, weight: .bold))
                            .foregroundColor(controller.isDropTargeted ? (isNotchAttached ? .black : theme.onPrimary) : theme.primary)
                        Text(controller.isDropTargeted ? "Drop to Shelf" : "DankDrop")
                            .font(theme.font(size: 11, weight: .semibold))
                            .foregroundColor(controller.isDropTargeted ? (isNotchAttached ? .black : theme.onPrimary) : (isNotchAttached ? .white : theme.onSurface))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(controller.isDropTargeted ? (isNotchAttached ? Color.white : theme.primary) : theme.surfaceContainerHigh.opacity(0.6))
                    .clipShape(Capsule())
                } else if activity == .media || nowPlaying.currentTrack.isPlaying {
                    Image(systemName: "waveform")
                        .font(ThemeStore.shared.font(size: 11, weight: .bold))
                        .foregroundColor(theme.primary)
                    Text(nowPlaying.currentTrack.title.isEmpty ? "Playing" : nowPlaying.currentTrack.title)
                        .font(theme.font(size: 11, weight: .semibold))
                        .foregroundColor(isNotchAttached ? .white : theme.onSurface)
                        .lineLimit(1)
                } else {
                    Image(systemName: "sparkles")
                        .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                        .foregroundColor(theme.primary)
                    Text("DMS")
                        .font(theme.font(size: 11, weight: .bold))
                        .foregroundColor(isNotchAttached ? .white : theme.onSurface)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.leading, useGothFillets ? 18 : 12)
            .padding(.trailing, 10)
            .frame(width: isNotchAttached ? wingWidth : nil, alignment: .leading)
            .clipped()

            if isNotchAttached {
                // Hardware Notch Center Exclusion Gap
                Spacer(minLength: notchWidth)
                    .frame(width: notchWidth)
            } else {
                Spacer(minLength: 12)
            }

            // Right Wing (Right of hardware notch)
            HStack(spacing: 5) {
                if activity == .osd, let payload = payload {
                    if let prog = payload.progress {
                        Capsule()
                            .fill(theme.surfaceContainerHighest.opacity(0.8))
                            .frame(width: 44, height: 4)
                            .overlay(
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(theme.primary)
                                        .frame(width: max(4, geo.size.width * CGFloat(min(1, max(0, prog)))), height: 4)
                                },
                                alignment: .leading
                            )

                        Text("\(Int(round(prog * 100)))%")
                            .font(theme.font(size: 10, weight: .bold, mono: true))
                            .foregroundColor(isNotchAttached ? .white : theme.onSurface)
                            .lineLimit(1)
                    } else {
                        // Non-gauge OSDs (capsLock / audioOutput / idleInhibit) already print the
                        // label in the left wing — keep the right wing empty instead of duplicating it.
                        EmptyView()
                    }
                } else if activity == .timer {
                    // Progress dot: ring fills as the current Pomodoro phase elapses
                    let phaseTotal = pomodoro.isBreak
                        ? (pomodoro.completedSessions % 4 == 0 ? 15 * 60 : 5 * 60)
                        : 25 * 60
                    let progress = phaseTotal > 0
                        ? CGFloat(max(0.0, min(1.0, 1.0 - Double(pomodoro.remainingSeconds) / Double(phaseTotal))))
                        : 0
                    ZStack {
                        Circle()
                            .stroke(theme.surfaceContainerHighest.opacity(0.9), lineWidth: 2.5)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(theme.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 12, height: 12)
                } else if activity == .fileDrop {
                    if !controller.dropStore.items.isEmpty {
                        Text("\(controller.dropStore.items.count)")
                            .font(theme.font(size: 10, weight: .bold, mono: true))
                            .foregroundColor(isNotchAttached ? .white : theme.onSurface)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.primary.opacity(0.25))
                            .clipShape(Capsule())
                    } else {
                        EmptyView()
                    }
                } else {
                    let isCelsius = configStore.config.weatherUnits.lowercased() == "celsius"
                    let temp = isCelsius ? weather.currentWeather.temperatureC : weather.currentWeather.temperatureF
                    Image(systemName: weather.currentWeather.sfSymbol)
                        .font(ThemeStore.shared.font(size: 10, weight: .medium))
                        .foregroundColor(theme.primary)
                    Text("\(Int(round(temp)))°")
                        .font(theme.font(size: 11, weight: .semibold, mono: true))
                        .foregroundColor(isNotchAttached ? .white : theme.onSurface)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, useGothFillets ? 18 : 12)
            .frame(width: isNotchAttached ? wingWidth : nil, alignment: .trailing)
            .clipped()
        }
    }
}

// MARK: - Expanded Island Content (leaf container with activity header)

private struct ExpandedIslandContent: View {
    @ObservedObject var controller: DIslandController
    let activity: IslandActivity
    let settings: IslandSettings
    let useGothFillets: Bool
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        VStack(spacing: 8) {
            // Top Activity Switcher Header
            HStack(spacing: 6) {
                // `.notification` is intentionally excluded from the user-clickable tabs:
                // notifications surface via the island's own toast/notification flow, not a tab.
                ForEach([IslandActivity.home, .media, .controlCenter, .dash, .clipboard, .weather, .timer, .fileDrop].filter { $0 != .notification }, id: \.rawValue) { act in
                    if settings.enabledActivities.contains(act.rawValue) || act == .home || act == .timer || act == .fileDrop {
                        Button {
                            controller.open(activity: act)
                        } label: {
                            Image(systemName: iconForActivity(act))
                                .font(ThemeStore.shared.font(size: 11, weight: activity == act ? .bold : .medium))
                                .foregroundColor(activity == act ? theme.onPrimary : theme.onSurfaceVariant)
                                .frame(width: 24, height: 20)
                                .background(activity == act ? theme.primary : theme.surfaceContainerHigh.opacity(0.6))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Button {
                    controller.close()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(ThemeStore.shared.font(size: 13))
                        .foregroundColor(theme.onSurfaceVariant)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            Divider().opacity(0.2)

            Group {
                switch activity {
                case .media:
                    ExpandedMediaView(controller: controller)
                case .osd:
                    ExpandedOSDView(controller: controller)
                case .notification:
                    ExpandedNotificationView(controller: controller)
                case .controlCenter:
                    ExpandedPanelContainer(controller: controller) { ControlCenterView() }
                case .dash:
                    ExpandedPanelContainer(controller: controller) {
                        DashView(initialTab: DashController.shared.activeTab, onClose: { controller.close() })
                    }
                case .clipboard:
                    ExpandedClipboardView(controller: controller)
                case .weather:
                    ExpandedWeatherView()
                case .powerMenu:
                    ExpandedPowerMenuView(controller: controller)
                case .timer:
                    ExpandedTimerView(controller: controller)
                case .fileDrop:
                    ExpandedFileDropView(controller: controller)
                case .launcher, .home:
                    ExpandedHomeView(controller: controller)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func iconForActivity(_ activity: IslandActivity) -> String {
        switch activity {
        case .home: return "square.grid.2x2.fill"
        case .media: return "music.note"
        case .notification: return "bell.fill"
        case .osd: return "speaker.wave.2.fill"
        case .controlCenter: return "switch.2"
        case .dash: return "square.stack.3d.up.fill"
        case .launcher: return "magnifyingglass"
        case .clipboard: return "doc.on.clipboard"
        case .powerMenu: return "power"
        case .weather: return "cloud.sun.fill"
        case .timer: return "timer"
        case .fileDrop: return "tray.and.arrow.down.fill"
        }
    }
}

/// Close header wrapper for full-panel activities (Control Center / Dash) so the user is
/// never trapped in an expanded island without a visible close button.
private struct ExpandedPanelContainer<Content: View>: View {
    @ObservedObject var controller: DIslandController
    @ObservedObject private var theme = ThemeStore.shared
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button {
                    controller.close()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(ThemeStore.shared.font(size: 13))
                        .foregroundColor(theme.onSurfaceVariant)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Expanded Activity Leaves

private struct ExpandedHomeView: View {
    @ObservedObject var controller: DIslandController
    @ObservedObject private var theme = ThemeStore.shared
    private let telemetry = TelemetryService.shared
    private let battery = BatteryService.shared

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                IslandMetricPill(
                    icon: "cpu",
                    title: "CPU",
                    value: "\(Int(telemetry.telemetry.cpuPercent))%",
                    tint: theme.primary
                )
                IslandMetricPill(
                    icon: "memorychip",
                    title: "RAM",
                    value: "\(Int(telemetry.telemetry.ramPercent))%",
                    tint: theme.secondary
                )
                if let bat = battery.status {
                    IslandMetricPill(
                        icon: bat.isCharging ? "battery.100.bolt" : "battery.75",
                        title: "Battery",
                        value: "\(bat.capacity)%",
                        tint: theme.success
                    )
                }
            }

            HStack(spacing: 8) {
                IslandActionButton(icon: "magnifyingglass", label: "Search") {
                    controller.close()
                    LauncherController.shared.toggle()
                }
                IslandActionButton(icon: "slider.horizontal.3", label: "Controls") {
                    controller.open(activity: .controlCenter)
                }
                IslandActionButton(icon: "doc.on.clipboard", label: "Clips") {
                    controller.open(activity: .clipboard)
                }
                IslandActionButton(icon: "gearshape.fill", label: "Settings") {
                    controller.close()
                    SettingsController.shared.show()
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct ExpandedMediaView: View {
    @ObservedObject var controller: DIslandController
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared
    @ObservedObject private var lyrics = LyricsService.shared
    // Album artwork is decoded once per artwork change, never inside `body` at 60Hz.
    @State private var cachedArtwork: NSImage?

    var body: some View {
        let track = nowPlaying.currentTrack
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.primaryContainer.opacity(0.4))
                        .frame(width: 48, height: 48)
                    if let img = cachedArtwork {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "music.note")
                            .font(ThemeStore.shared.font(size: 20, weight: .bold))
                            .foregroundColor(theme.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title.isEmpty ? "No Track Playing" : track.title)
                        .font(theme.font(size: 13, weight: .bold))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)
                    Text(track.artist.isEmpty ? track.appName : track.artist)
                        .font(theme.font(size: 11, weight: .medium))
                        .foregroundColor(theme.onSurfaceVariant)
                        .lineLimit(1)

                    // Live synchronized lyric line (LyricsService)
                    if !lyrics.activeLineText.isEmpty {
                        Text(lyrics.activeLineText)
                            .font(theme.font(size: 11, weight: .semibold))
                            .foregroundColor(theme.primary)
                            .lineLimit(1)
                            .id(lyrics.activeLineIndex ?? -1)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: lyrics.activeLineIndex)

                Spacer()

                HStack(spacing: 10) {
                    Button(action: { nowPlaying.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(ThemeStore.shared.font(size: 13))
                            .foregroundColor(theme.onSurface)
                    }
                    .buttonStyle(.plain)

                    Button(action: { nowPlaying.playPause() }) {
                        Image(systemName: track.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(ThemeStore.shared.font(size: 24))
                            .foregroundColor(theme.primary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { nowPlaying.next() }) {
                        Image(systemName: "forward.fill")
                            .font(ThemeStore.shared.font(size: 13))
                            .foregroundColor(theme.onSurface)
                    }
                    .buttonStyle(.plain)
                }
            }

            if track.durationSeconds > 0 {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(theme.surfaceContainerHighest)
                                .frame(height: 4)
                            Capsule()
                                .fill(theme.primary)
                                .frame(width: max(4, geo.size.width * CGFloat(track.progress)), height: 4)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text(track.formattedElapsed)
                            .font(ThemeStore.shared.font(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                        Spacer()
                        Text(track.formattedDuration)
                            .font(ThemeStore.shared.font(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                }
            }
        }
        .padding(.top, 4)
        .onAppear {
            cachedArtwork = track.artworkData.flatMap { NSImage(data: $0) }
            lyrics.addConsumer("island.media")
        }
        .onDisappear { lyrics.removeConsumer("island.media") }
        .onChange(of: nowPlaying.currentTrack.artworkData) { _, newData in
            cachedArtwork = newData.flatMap { NSImage(data: $0) }
        }
    }
}

private struct ExpandedOSDView: View {
    @ObservedObject var controller: DIslandController
    @ObservedObject private var theme = ThemeStore.shared
    private let audio = AudioService.shared

    var body: some View {
        let payload = controller.osdPayload ?? (icon: audio.currentOutputIcon, label: "Volume", progress: audio.volume)
        return HStack(spacing: 12) {
            Image(systemName: payload.icon)
                .font(ThemeStore.shared.font(size: 16, weight: .bold))
                .foregroundColor(theme.primary)
                .frame(width: 24)

            Text(payload.label)
                .font(theme.font(size: 12, weight: .semibold))
                .foregroundColor(theme.onSurface)

            if let prog = payload.progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.surfaceContainerHighest)
                            .frame(height: 6)
                        Capsule()
                            .fill(theme.primary)
                            .frame(width: max(6, geo.size.width * CGFloat(min(1, max(0, prog)))), height: 6)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 14)

                Text("\(Int(round(prog * 100)))%")
                    .font(theme.font(size: 11, weight: .bold, mono: true))
                    .foregroundColor(theme.onSurfaceVariant)
                    .frame(width: 36, alignment: .trailing)
            } else {
                // Non-gauge OSDs already print the label on the left — no duplicate badge here.
                Spacer()
            }
        }
    }
}

private struct ExpandedNotificationView: View {
    @ObservedObject var controller: DIslandController
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        let toast = controller.toastPayload ?? (title: "DMS Notification", body: "No unread notifications", level: "info")
        return HStack(spacing: 10) {
            Image(systemName: toast.level == "error" ? "exclamationmark.triangle.fill" : "bell.badge.fill")
                .font(ThemeStore.shared.font(size: 18))
                .foregroundColor(toast.level == "error" ? theme.error : theme.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(theme.font(size: 12, weight: .bold))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)
                Text(toast.body)
                    .font(theme.font(size: 11))
                    .foregroundColor(theme.onSurfaceVariant)
                    .lineLimit(2)
            }
            Spacer()
        }
    }
}

private struct ExpandedControlCenterView: View {
    @ObservedObject var controller: DIslandController
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared
    private let audio = AudioService.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                IslandActionButton(
                    icon: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    label: audio.isMuted ? "Muted" : "\(Int(audio.volume * 100))%"
                ) {
                    audio.toggleMute()
                }
                IslandActionButton(
                    icon: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer",
                    label: inhibit.isInhibited ? "Awake" : "Normal"
                ) {
                    inhibit.toggle()
                }
                IslandActionButton(
                    icon: theme.isLightMode ? "sun.max.fill" : "moon.fill",
                    label: theme.isLightMode ? "Light" : "Dark"
                ) {
                    ConfigStore.shared.update { $0.isLightMode.toggle() }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: audio.currentOutputIcon)
                    .font(ThemeStore.shared.font(size: 12, weight: .semibold))
                    .foregroundColor(theme.primary)
                    .frame(width: 16)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.surfaceContainerHighest)
                        Capsule()
                            .fill(theme.primary)
                            .frame(width: max(6, geo.size.width * CGFloat(min(1, max(0, audio.volume)))))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard geo.size.width > 0 else { return }
                                let newVol = min(1.0, max(0.0, Double(value.location.x / geo.size.width)))
                                audio.setVolume(newVol)
                            }
                    )
                }
                .frame(height: 10)
                .accessibilityLabel("Volume")
                .accessibilityValue("\(Int(round(audio.volume * 100))) percent")

                Text("\(Int(round(audio.volume * 100)))%")
                    .font(theme.font(size: 11, weight: .bold, mono: true))
                    .foregroundColor(theme.onSurfaceVariant)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(theme.surfaceContainerHigh.opacity(0.45))
            .cornerRadius(8)

            HStack(spacing: 8) {
                IslandActionButton(icon: "gearshape.fill", label: "Settings") {
                    controller.close()
                    SettingsController.shared.show()
                }
                IslandActionButton(icon: "lock.fill", label: "Lock") {
                    controller.close()
                    _ = IPCCommandExecutor.execute(.powerMenuAction("lock"))
                }
                IslandActionButton(icon: "power", label: "Power") {
                    controller.close()
                    PowerMenuController.shared.toggle()
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct ExpandedClipboardView: View {
    @ObservedObject var controller: DIslandController
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var clipboard = ClipboardService.shared
    @State private var query: String = ""
    /// Session-local pins (ClipboardItem has no persisted pin flag): pinned items sort first.
    @State private var pinned: Set<UUID> = []

    /// Case-insensitive live filter over the live service items, pinned first, capped at 30 rows.
    private var filtered: [ClipboardItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base: [ClipboardItem]
        if q.isEmpty {
            base = clipboard.items
        } else {
            base = clipboard.items.filter { $0.text.lowercased().contains(q) }
        }
        let pinnedItems = base.filter { pinned.contains($0.id) }
        let unpinnedItems = base.filter { !pinned.contains($0.id) }
        return Array((pinnedItems + unpinnedItems).prefix(30))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Live search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                    .foregroundColor(theme.onSurfaceVariant)
                TextField("Search clipboard", text: $query)
                    .textFieldStyle(.plain)
                    .font(theme.font(size: 11))
                    .foregroundColor(theme.onSurface)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(ThemeStore.shared.font(size: 10))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(theme.surfaceContainerHigh.opacity(0.6))
            .cornerRadius(8)

            if filtered.isEmpty {
                Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Clipboard is empty" : "No matches")
                    .font(theme.font(size: 11))
                    .foregroundColor(theme.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filtered) { item in
                            clipboardRow(item)
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func clipboardRow(_ item: ClipboardItem) -> some View {
        HStack(spacing: 6) {
            Button {
                clipboard.copyItem(text: item.text)
                controller.close()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: pinned.contains(item.id) ? "pin.fill" : "doc.on.doc")
                        .font(ThemeStore.shared.font(size: 10))
                        .foregroundColor(pinned.contains(item.id) ? theme.primary : theme.onSurfaceVariant)
                    Text(item.text.replacingOccurrences(of: "\n", with: " "))
                        .font(theme.font(size: 11, mono: true))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Pin / Copy / Paste / Delete actions
            Button {
                if pinned.contains(item.id) {
                    pinned.remove(item.id)
                } else {
                    pinned.insert(item.id)
                }
            } label: {
                Image(systemName: pinned.contains(item.id) ? "pin.slash.fill" : "pin")
                    .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                    .foregroundColor(pinned.contains(item.id) ? theme.primary : theme.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(pinned.contains(item.id) ? "Unpin" : "Pin")

            Button {
                clipboard.copyItem(text: item.text)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                    .foregroundColor(theme.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy")

            Button {
                clipboard.copyItem(text: item.text)
                controller.close()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                    .foregroundColor(theme.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Paste")

            Button {
                pinned.remove(item.id)
                clipboard.removeItem(id: item.id)
            } label: {
                Image(systemName: "trash")
                    .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                    .foregroundColor(theme.error)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(theme.surfaceContainerHigh.opacity(0.6))
        .cornerRadius(6)
    }
}

// MARK: - Expanded Pomodoro Timer (Live Activity)

private struct ExpandedTimerView: View {
    @ObservedObject var controller: DIslandController
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var pomodoro = PomodoroService.shared

    /// Total seconds of the current phase (mirrors PomodoroService.advancePhase durations).
    private var phaseTotalSeconds: Int {
        if pomodoro.isBreak {
            return (pomodoro.completedSessions % 4 == 0) ? 15 * 60 : 5 * 60
        }
        return 25 * 60
    }

    private var phaseProgress: CGFloat {
        let total = Double(phaseTotalSeconds)
        guard total > 0 else { return 0 }
        return CGFloat(max(0.0, min(1.0, 1.0 - Double(pomodoro.remainingSeconds) / total)))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                // Large MM:SS countdown inside a circular progress ring
                ZStack {
                    Circle()
                        .stroke(theme.surfaceContainerHighest, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: phaseProgress)
                        .stroke(theme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(pomodoro.phaseLabel)
                            .font(theme.font(size: 10, weight: .bold))
                            .foregroundColor(theme.primary)
                        Text(pomodoro.formattedRemaining)
                            .font(theme.font(size: 26, weight: .bold, mono: true))
                            .foregroundColor(theme.onSurface)
                    }
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pomodoro.isBreak ? "Break" : "Focus")
                        .font(theme.font(size: 15, weight: .bold))
                        .foregroundColor(theme.onSurface)
                    Text(pomodoro.isRunning ? "Session in progress" : "Paused")
                        .font(theme.font(size: 11))
                        .foregroundColor(theme.onSurfaceVariant)
                    Text("\(pomodoro.completedSessions) completed")
                        .font(theme.font(size: 10, mono: true))
                        .foregroundColor(theme.onSurfaceVariant)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                IslandActionButton(
                    icon: pomodoro.isRunning ? "pause.fill" : "play.fill",
                    label: pomodoro.isRunning ? "Pause" : "Start"
                ) {
                    pomodoro.toggleStartPause()
                }
                IslandActionButton(icon: "forward.end.fill", label: "Skip") {
                    pomodoro.skipPhase()
                }
                IslandActionButton(icon: "arrow.counterclockwise", label: "Reset") {
                    pomodoro.reset()
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Expanded DankDrop Shelf (File-Drop Target)

private struct ExpandedFileDropView: View {
    @ObservedObject var controller: DIslandController
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(ThemeStore.shared.font(size: 13, weight: .bold))
                    .foregroundColor(theme.primary)
                Text("DankDrop")
                    .font(theme.font(size: 13, weight: .bold))
                    .foregroundColor(theme.onSurface)
                Text("\(controller.dropStore.items.count)/\(controller.dropStore.maxItems)")
                    .font(theme.font(size: 10, mono: true))
                    .foregroundColor(theme.onSurfaceVariant)
                Spacer()
                if !controller.dropStore.items.isEmpty {
                    Button {
                        controller.clearDroppedItems()
                    } label: {
                        Text("Clear All")
                            .font(theme.font(size: 10, weight: .semibold))
                            .foregroundColor(theme.error)
                    }
                    .buttonStyle(.plain)
                }
            }

            if controller.dropStore.items.isEmpty {
                // Dashed drop prompt
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(theme.font(size: 22, weight: .semibold))
                        .foregroundColor(theme.primary)
                    Text("Drop files, links, or text onto the island")
                        .font(theme.font(size: 11))
                        .foregroundColor(theme.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundColor(theme.outlineVariant)
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220))], spacing: 8) {
                        ForEach(controller.dropStore.items) { item in
                            DankDropCard(controller: controller, item: item)
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct DankDropCard: View {
    @ObservedObject var controller: DIslandController
    let item: DankDropItem
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: item.sfSymbol)
                    .font(ThemeStore.shared.font(size: 16, weight: .bold))
                    .foregroundColor(theme.primary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(theme.font(size: 11, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(theme.font(size: 9))
                        .foregroundColor(theme.onSurfaceVariant)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                if let urlString = item.urlString, let url = URL(string: urlString) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Label("Reveal", systemImage: "finder")
                            .font(theme.font(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.primary)
                    Button {
                        copyToPasteboard(url.path)
                    } label: {
                        Label("Copy Path", systemImage: "doc.on.doc")
                            .font(theme.font(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.onSurfaceVariant)
                } else if let text = item.textPayload {
                    Button {
                        copyToPasteboard(text)
                    } label: {
                        Label("Copy Text", systemImage: "doc.on.doc")
                            .font(theme.font(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.onSurfaceVariant)
                }
                Spacer()
                Button {
                    controller.removeDroppedItem(id: item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(ThemeStore.shared.font(size: 12))
                        .foregroundColor(theme.onSurfaceVariant)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove")
            }
        }
        .padding(8)
        .background(theme.cardBackground)
        .cornerRadius(10)
        // Drag-out: re-offer the file URL (or text) so items can be dragged elsewhere
        .onDrag {
            if let urlString = item.urlString, let url = URL(string: urlString) {
                return NSItemProvider(object: url as NSURL)
            } else if let text = item.textPayload {
                return NSItemProvider(object: text as NSString)
            }
            return NSItemProvider()
        }
    }

    private func copyToPasteboard(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }
}

private struct ExpandedWeatherView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared
    @ObservedObject private var weather = WeatherService.shared

    var body: some View {
        let isCelsius = configStore.config.weatherUnits.lowercased() == "celsius"
        let w = weather.currentWeather
        let temp = isCelsius ? w.temperatureC : w.temperatureF
        let apparent = isCelsius ? w.apparentTemperatureC : (w.apparentTemperatureC * 9.0 / 5.0 + 32.0)
        let unit = isCelsius ? "°C" : "°F"

        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: w.sfSymbol)
                    .font(ThemeStore.shared.font(size: 28))
                    .foregroundColor(theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(round(temp)))\(unit) • \(w.conditionDescription)")
                        .font(theme.font(size: 13, weight: .bold))
                        .foregroundColor(theme.onSurface)
                    Text(w.locationName)
                        .font(theme.font(size: 11))
                        .foregroundColor(theme.onSurfaceVariant)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                IslandMetricPill(
                    icon: "thermometer.medium",
                    title: "Feels Like",
                    value: "\(Int(round(apparent)))\(unit)",
                    tint: theme.primary
                )
                IslandMetricPill(
                    icon: "humidity.fill",
                    title: "Humidity",
                    value: "\(w.humidity)%",
                    tint: theme.secondary
                )
                IslandMetricPill(
                    icon: "wind",
                    title: "Wind",
                    value: "\(Int(round(w.windSpeedKmh))) km/h",
                    tint: theme.tertiary
                )
            }
        }
        .padding(.top, 4)
    }
}

private struct ExpandedPowerMenuView: View {
    @ObservedObject var controller: DIslandController

    var body: some View {
        HStack(spacing: 8) {
            IslandActionButton(icon: "lock.fill", label: "Lock") {
                controller.close()
                _ = IPCCommandExecutor.execute(.powerMenuAction("lock"))
            }
            IslandActionButton(icon: "moon.zzz.fill", label: "Sleep") {
                controller.close()
                _ = IPCCommandExecutor.execute(.powerMenuAction("sleep"))
            }
            IslandActionButton(icon: "power", label: "Power") {
                controller.close()
                PowerMenuController.shared.toggle()
            }
        }
    }
}
private struct IslandMetricPill: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(ThemeStore.shared.font(size: 9, weight: .medium))
                    .foregroundColor(theme.onSurfaceVariant)
                Text(value)
                    .font(ThemeStore.shared.font(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.onSurface)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(theme.cardBackground)
        .cornerRadius(8)
    }
}

private struct IslandActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                    .foregroundColor(theme.primary)
                Text(label)
                    .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(theme.cardBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
