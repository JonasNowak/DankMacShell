import SwiftUI
import AppKit
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
            let f = min(filletRadius, rect.width * 0.15, rect.height * 0.45)
            let br = min(rBR, (rect.width - 2 * f) * 0.5, rect.height * 0.5)
            let bl = min(rBL, (rect.width - 2 * f) * 0.5, rect.height * 0.5)

            // Start at top-left outer flange
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            // Top edge across to top-right outer flange
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            // Concave fillet curving inward-downward on right
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - f, y: rect.minY + f),
                control: CGPoint(x: rect.maxX - f, y: rect.minY)
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
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.minY),
                control: CGPoint(x: rect.minX + f, y: rect.minY)
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
    @ObservedObject private var nowPlaying = NowPlayingService.shared
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var inhibit = IdleInhibitService.shared
    @ObservedObject private var clipboard = ClipboardService.shared
    private let telemetry = TelemetryService.shared
    private let audio = AudioService.shared
    private let battery = BatteryService.shared

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
        settings.gothCorners && (isNotchAttached || (settings.float && settings.edge.lowercased() == "top") || settings.instance == .notch)
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
                    expandedContent(activity: controller.presentationState.activity)
                        .padding(.horizontal, useGothFillets ? 18 : 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    compactContent(activity: controller.presentationState.activity)
                        .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(shape)
        .onHover { hovering in
            controller.setHovered(hovering)
        }
        .onTapGesture {
            if !controller.presentationState.isExpanded {
                controller.toggle()
            }
        }
    }

    @ViewBuilder
    private var islandBackground: some View {
        if isNotchAttached && !controller.presentationState.isExpanded {
            Color.black.opacity(max(0.95, settings.opacity))
        } else if settings.opacity < 1.0 {
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                .background(
                    (isNotchAttached ? Color.black : theme.surfaceContainerHighest)
                        .opacity(settings.opacity)
                )
        } else {
            isNotchAttached ? Color.black : theme.surfaceContainerHighest
        }
    }

    // MARK: - Compact / Idle State

    @ViewBuilder
    private func compactContent(activity: IslandActivity) -> some View {
        let notchWidth = isNotchAttached ? CGFloat(controller.currentNotch.notchWidth) : 0
        let gothFlange: CGFloat = useGothFillets ? 14.0 : 0.0
        let totalW = CGFloat(controller.currentGeometry.width) + gothFlange * 2
        let wingWidth = isNotchAttached ? max(84.0, (totalW - notchWidth) / 2.0) : (totalW / 2.0 - 6.0)

        HStack(spacing: 0) {
            // Left Wing (Left of hardware notch)
            HStack(spacing: 5) {
                if activity == .media || nowPlaying.currentTrack.isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.primary)
                    Text(nowPlaying.currentTrack.title.isEmpty ? "Playing" : nowPlaying.currentTrack.title)
                        .font(theme.font(size: 11, weight: .semibold))
                        .foregroundColor(isNotchAttached ? .white : theme.onSurface)
                        .lineLimit(1)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
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
                let isCelsius = configStore.config.weatherUnits.lowercased() == "celsius"
                let temp = isCelsius ? weather.currentWeather.temperatureC : weather.currentWeather.temperatureF
                Image(systemName: weather.currentWeather.sfSymbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.primary)
                Text("\(Int(round(temp)))°")
                    .font(theme.font(size: 11, weight: .semibold, mono: true))
                    .foregroundColor(isNotchAttached ? .white : theme.onSurface)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.leading, 10)
            .padding(.trailing, useGothFillets ? 18 : 12)
            .frame(width: isNotchAttached ? wingWidth : nil, alignment: .trailing)
            .clipped()
        }
    }

    // MARK: - Expanded Activity Drawers

    @ViewBuilder
    private func expandedContent(activity: IslandActivity) -> some View {
        VStack(spacing: 8) {
            // Top Activity Switcher Header
            HStack(spacing: 6) {
                ForEach([IslandActivity.home, .media, .controlCenter, .clipboard, .weather], id: \.rawValue) { act in
                    if settings.enabledActivities.contains(act.rawValue) || act == .home {
                        Button {
                            controller.open(activity: act)
                        } label: {
                            Image(systemName: iconForActivity(act))
                                .font(.system(size: 11, weight: activity == act ? .bold : .medium))
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
                        .font(.system(size: 13))
                        .foregroundColor(theme.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }

            Divider().opacity(0.2)

            Group {
                switch activity {
                case .media:
                    expandedMediaView
                case .osd:
                    expandedOSDView
                case .notification:
                    expandedNotificationView
                case .controlCenter:
                    expandedControlCenterView
                case .clipboard:
                    expandedClipboardView
                case .weather:
                    expandedWeatherView
                case .powerMenu:
                    expandedPowerMenuView
                case .launcher, .home:
                    expandedHomeView
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
        case .launcher: return "magnifyingglass"
        case .clipboard: return "doc.on.clipboard"
        case .powerMenu: return "power"
        case .weather: return "cloud.sun.fill"
        }
    }

    private var expandedHomeView: some View {
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

    private var expandedMediaView: some View {
        let track = nowPlaying.currentTrack
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.primaryContainer.opacity(0.4))
                        .frame(width: 48, height: 48)
                    if let data = track.artworkData, let nsImg = NSImage(data: data) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 20, weight: .bold))
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
                }

                Spacer()

                HStack(spacing: 10) {
                    Button(action: { nowPlaying.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13))
                            .foregroundColor(theme.onSurface)
                    }
                    .buttonStyle(.plain)

                    Button(action: { nowPlaying.playPause() }) {
                        Image(systemName: track.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(theme.primary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { nowPlaying.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
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
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                        Spacer()
                        Text(track.formattedDuration)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.onSurfaceVariant)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private var expandedOSDView: some View {
        let payload = controller.osdPayload ?? (icon: audio.currentOutputIcon, label: "Volume", progress: audio.volume)
        return HStack(spacing: 10) {
            Image(systemName: payload.icon)
                .font(.system(size: 15, weight: .bold))
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
            }
        }
    }

    private var expandedNotificationView: some View {
        let toast = controller.toastPayload ?? (title: "DMS Notification", body: "No unread notifications", level: "info")
        return HStack(spacing: 10) {
            Image(systemName: toast.level == "error" ? "exclamationmark.triangle.fill" : "bell.badge.fill")
                .font(.system(size: 18))
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

    private var expandedControlCenterView: some View {
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
                    .font(.system(size: 12, weight: .semibold))
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
                                let newVol = min(1.0, max(0.0, Double(value.location.x / geo.size.width)))
                                audio.setVolume(newVol)
                            }
                    )
                }
                .frame(height: 10)

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

    private var expandedClipboardView: some View {
        let recent = Array(clipboard.items.prefix(3))
        return VStack(alignment: .leading, spacing: 5) {
            if recent.isEmpty {
                Text("Clipboard is empty")
                    .font(theme.font(size: 11))
                    .foregroundColor(theme.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
            } else {
                ForEach(recent) { item in
                    Button {
                        clipboard.copyItem(text: item.text)
                        controller.close()
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(theme.primary)
                            Text(item.text.replacingOccurrences(of: "\n", with: " "))
                                .font(theme.font(size: 11, mono: true))
                                .foregroundColor(theme.onSurface)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(theme.surfaceContainerHigh.opacity(0.6))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 4)
    }

    private var expandedWeatherView: some View {
        let isCelsius = configStore.config.weatherUnits.lowercased() == "celsius"
        let w = weather.currentWeather
        let temp = isCelsius ? w.temperatureC : w.temperatureF
        let apparent = isCelsius ? w.apparentTemperatureC : (w.apparentTemperatureC * 9.0 / 5.0 + 32.0)
        let unit = isCelsius ? "°C" : "°F"

        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: w.sfSymbol)
                    .font(.system(size: 28))
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

    private var expandedPowerMenuView: some View {
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.onSurfaceVariant)
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.onSurface)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(theme.surfaceContainerHigh.opacity(0.65))
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
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.primary)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.onSurface)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(theme.surfaceContainerHigh.opacity(0.75))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
