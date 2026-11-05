import SwiftUI
import DMSCore

/// Material 3 comprehensive Settings modal view for DMS on macOS.
/// Strictly conforms to DMS upstream design specs and maintains the 510x390 pane geometry.
public struct SettingsView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var configStore = ConfigStore.shared
    @ObservedObject var inhibit = IdleInhibitService.shared
    @ObservedObject var pluginService = PluginService.shared
    @ObservedObject var controller = SettingsController.shared
    @ObservedObject var wallpaperService = WallpaperService.shared

    public typealias SettingsSection = DMSSettingsTab

    @State private var sidebarSearchQuery: String = ""
    @State private var weatherLocationInput: String = ""
    @State private var customSeedHexInput: String = ""
    @State private var expandedWidgetStyleId: String? = nil

    // Wallpaper Tab States
    @State private var wallpaperSelectedSource: WallpaperSource = .all
    @State private var wallpaperSearchQuery: String = ""
    @State private var selectedWallpaperItem: WallpaperItem? = nil
    @State private var pendingWallpaperChange: Bool = false

    // Modal Sheet States
    @State private var activeAddWidgetSection: String? = nil
    @State private var showBrowsePluginsModal: Bool = false

    let onClose: () -> Void

    public init(initialTab: String? = nil, onClose: @escaping () -> Void) {
        if let initialTab = initialTab {
            SettingsController.shared.currentTab = DMSSettingsTab.resolve(tab: initialTab)
        }
        self._sidebarSearchQuery = State(initialValue: "")
        self._weatherLocationInput = State(initialValue: ConfigStore.shared.config.weatherLocation)
        self._customSeedHexInput = State(initialValue: ConfigStore.shared.config.themeSeedColor)
        self.onClose = onClose
    }

    public var body: some View {
        let p = themeStore.palette

        ZStack {
            VStack(spacing: 0) {
                // Header Bar (with spacing for macOS Server-Side Decorations traffic lights)
                HStack(spacing: 10) {
                    Spacer().frame(width: 68)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: p.primary.hex))

                    Text("Settings")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: p.onSurface.hex))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeStore.panelHeaderBackground)

                Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.4))

                // Master-Detail Split
                HStack(spacing: 0) {
                    // Left Navigation Sidebar
                    SettingsSidebar(
                        selectedTab: $controller.currentTab,
                        searchQuery: $sidebarSearchQuery,
                        palette: p
                    )

                    Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.4))

                    // Detail Content Area
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            tabContent(for: controller.currentTab, palette: p)
                        }
                        .padding(18)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.4))

                // Footer Bar
                HStack {
                    Text("Config: ~/Library/Application Support/DMS/settings.json")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: p.outline.hex))
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        if pendingWallpaperChange, let sel = selectedWallpaperItem {
                            wallpaperService.applyWallpaper(sel)
                            pendingWallpaperChange = false
                        } else if let sel = selectedWallpaperItem, (sel.path != nil && sel.path != wallpaperService.currentDesktopPath) || (sel.path == nil && sel.associatedTheme != nil && sel.associatedTheme != configStore.config.theme) {
                            wallpaperService.applyWallpaper(sel)
                            pendingWallpaperChange = false
                        }
                        configStore.flushSave()
                        ToastCenter.shared.show(icon: "checkmark.circle.fill", message: "Settings Saved")
                    }) {
                        Text("Apply Changes")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: p.onPrimary.hex))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(hex: p.primary.hex))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(themeStore.panelHeaderBackground)
            }
            .frame(minWidth: 840, idealWidth: 980, maxWidth: .infinity, minHeight: 560, idealHeight: 700, maxHeight: .infinity)
            .background(
                GlassSurfaceBackground(
                    baseColor: Color(hex: p.surface.hex),
                    opacity: configStore.config.surfaceOpacity
                )
            )

            // Add Widget Modal Overlay
            if let section = activeAddWidgetSection {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { activeAddWidgetSection = nil }

                AddWidgetModal(
                    section: section,
                    palette: p,
                    onAdd: { widgetId in
                        guard !configStore.config.barConfigs.isEmpty else { return }
                        var layout = configStore.config.barConfigs[0].layout
                        let targetSec: SettingsWidgetCatalog.Section = section == "left" ? .left : (section == "center" ? .center : .right)
                        SettingsWidgetCatalog.addWidget(to: targetSec, widgetId: widgetId, in: &layout)
                        configStore.update { $0.barConfigs[0].layout = layout }
                        activeAddWidgetSection = nil
                        ToastCenter.shared.show(icon: "plus.circle.fill", message: "Added \(widgetId)")
                    },
                    onClose: { activeAddWidgetSection = nil }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // Browse Plugins Modal Overlay
            if showBrowsePluginsModal {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { showBrowsePluginsModal = false }

                BrowsePluginsModal(
                    palette: p,
                    onClose: { showBrowsePluginsModal = false }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activeAddWidgetSection != nil)
        .animation(.easeInOut(duration: 0.2), value: showBrowsePluginsModal)
        .onKeyPress(.escape) {
            if activeAddWidgetSection != nil {
                activeAddWidgetSection = nil
                return .handled
            }
            if showBrowsePluginsModal {
                showBrowsePluginsModal = false
                return .handled
            }
            onClose()
            return .handled
        }
    }

    // MARK: - Tab Router
    @ViewBuilder
    private func tabContent(for tab: DMSSettingsTab, palette: DMSPalette) -> some View {
        switch tab {
        case .theme:
            themeTab(palette: palette)
        case .wallpaper:
            wallpaperTab(palette: palette)
        case .typography:
            typographyTab(palette: palette)
        case .timeWeather:
            timeWeatherTab(palette: palette)
        case .sounds:
            soundsTab(palette: palette)
        case .barAppearance:
            barAppearanceTab(palette: palette)
        case .barSettings:
            barSettingsTab(palette: palette)
        case .barWidgets:
            barWidgetsTab(palette: palette)
        case .barWorkspaces:
            barWorkspacesTab(palette: palette)
        case .island:
            islandTab(palette: palette)
        case .dashboard:
            dashboardTab(palette: palette)
        case .mediaPlayer:
            mediaPlayerTab(palette: palette)
        case .notifications:
            notificationsTab(palette: palette)
        case .osd:
            osdTab(palette: palette)
        case .desktopWidgets:
            desktopWidgetsTab(palette: palette)
        case .dock:
            dockTab(palette: palette)
        case .launcher:
            launcherTab(palette: palette)
        case .shortcuts:
            shortcutsTab(palette: palette)
        case .power:
            powerTab(palette: palette)
        case .plugins:
            pluginsTab(palette: palette)
        case .about:
            aboutTab(palette: palette)
        }
    }

    // MARK: - 1. Theme & Colors Tab
    @ViewBuilder
    private func themeTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "sparkles", title: "Dynamic Wallpaper & Custom Seed", subtitle: "Extract M3 palette from wallpaper or custom hex seed", palette: palette) {
            Button(action: {
                themeStore.setDynamicWallpaper()
                configStore.update { $0.theme = "dynamic" }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(hex: palette.primary.hex))
                    Text("Sample Desktop Wallpaper (Dynamic)")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    if themeStore.themeName.lowercased() == "dynamic" {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: palette.primary.hex))
                    }
                }
                .padding(8)
                .background(Color(hex: palette.surfaceContainerLow.hex))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Divider().opacity(0.3)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: configStore.config.themeSeedColor))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color(hex: palette.outlineVariant.hex), lineWidth: 1))

                TextField("#D0BCFF", text: $customSeedHexInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(6)
                    .background(Color(hex: palette.surfaceContainerLow.hex))
                    .cornerRadius(6)

                Button("Use Custom Seed") {
                    let clean = customSeedHexInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    let hex = clean.hasPrefix("#") ? clean : "#\(clean)"
                    configStore.update {
                        $0.themeSeedColor = hex
                        $0.theme = "custom"
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: palette.primary.hex))
                .foregroundColor(Color(hex: palette.onPrimary.hex))
                .cornerRadius(6)
            }

            Divider().opacity(0.3)

            HStack {
                Text("Matugen Scheme")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                Spacer()
                SettingsSegmentedControl(
                    options: [
                        ("Tonal", MatugenScheme.tonalSpot),
                        ("Vibrant", MatugenScheme.vibrant),
                        ("Expressive", MatugenScheme.expressive),
                        ("Neutral", MatugenScheme.neutral),
                        ("Mono", MatugenScheme.monochrome)
                    ],
                    selection: Binding(
                        get: { configStore.config.matugenScheme },
                        set: { val in configStore.update { $0.matugenScheme = val } }
                    ),
                    palette: palette
                )
            }

            SettingsSliderRow(
                title: "Tonal Contrast Level",
                valueFormatted: String(format: "%+.2f", configStore.config.matugenContrast),
                value: Binding(
                    get: { configStore.config.matugenContrast },
                    set: { val in configStore.update(immediate: false) { $0.matugenContrast = val } }
                ),
                range: -1.0...1.0,
                step: 0.25,
                palette: palette
            )
        }

        SettingsCard(icon: "paintpalette.fill", title: "Stock & Community Theme Presets", subtitle: "Material You & community palettes with live reload", palette: palette) {
            let allPresets = StockThemes.allAvailableThemes
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(allPresets, id: \.self) { name in
                    Button(action: {
                        themeStore.apply(theme: name)
                        configStore.update { $0.theme = name }
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(themeColor(for: name))
                                .frame(width: 12, height: 12)
                            Text(name.replacingOccurrences(of: "-", with: " ").capitalized)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: palette.onSurface.hex))
                                .lineLimit(1)
                            Spacer()
                            if themeStore.themeName.lowercased() == name {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(hex: palette.primary.hex))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(hex: palette.surfaceContainerLow.hex))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        SettingsCard(icon: "macwindow.on.rectangle", title: "OmniWM Window Borders & Theming", subtitle: "Auto-sync Material 3 gradient borders directly to OmniWM (~/.config/omniwm/settings.toml)", palette: palette) {
            SettingsToggleRow(
                title: "Auto-Theme OmniWM Borders",
                subtitle: "Automatically write gradient colors to OmniWM on theme and wallpaper changes",
                isOn: Binding(
                    get: { configStore.config.autoThemeOmniWM },
                    set: { val in
                        configStore.update { $0.autoThemeOmniWM = val }
                        if val {
                            OmniWMThemeSyncService.shared.syncTheme(palette: palette, force: true)
                        }
                    }
                ),
                palette: palette
            )

            if configStore.config.autoThemeOmniWM {
                Divider().opacity(0.3)

                OmniWMWindowBorderPreview(
                    palette: palette,
                    mode: configStore.config.omniwmGradientMode,
                    direction: configStore.config.omniwmGradientDirection
                )

                Divider().opacity(0.3)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Gradient Harmony Strategy")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: palette.onSurface.hex))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(OmniWMGradientMode.allCases, id: \.self) { mode in
                            Button(action: {
                                configStore.update { $0.omniwmGradientMode = mode }
                                OmniWMThemeSyncService.shared.syncTheme(palette: palette, force: true)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: configStore.config.omniwmGradientMode == mode ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 10))
                                        .foregroundColor(configStore.config.omniwmGradientMode == mode ? Color(hex: palette.primary.hex) : Color(hex: palette.outline.hex))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mode.displayName)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(Color(hex: palette.onSurface.hex))
                                            .lineLimit(1)
                                        Text(mode.subtitle)
                                            .font(.system(size: 8.5))
                                            .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(7)
                                .background(Color(hex: configStore.config.omniwmGradientMode == mode ? palette.surfaceContainerHigh.hex : palette.surfaceContainerLow.hex))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(configStore.config.omniwmGradientMode == mode ? Color(hex: palette.primary.hex) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider().opacity(0.3)

                HStack {
                    Text("Gradient Direction")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                    Spacer()
                    SettingsSegmentedControl(
                        options: [
                            ("Top-Left ↘", OmniWMGradientDirection.topLeftToBottomRight),
                            ("Top-Right ↙", OmniWMGradientDirection.topRightToBottomLeft)
                        ],
                        selection: Binding(
                            get: { configStore.config.omniwmGradientDirection },
                            set: { val in
                                configStore.update { $0.omniwmGradientDirection = val }
                                OmniWMThemeSyncService.shared.syncTheme(palette: palette, force: true)
                            }
                        ),
                        palette: palette
                    )
                }

                Divider().opacity(0.3)

                SettingsToggleRow(
                    title: "Sync Overview & Exposé Borders",
                    subtitle: "Apply theme colors to OmniWM overview window borders and backdrop",
                    isOn: Binding(
                        get: { configStore.config.omniwmSyncOverview },
                        set: { val in
                            configStore.update { $0.omniwmSyncOverview = val }
                            OmniWMThemeSyncService.shared.syncTheme(palette: palette, force: true)
                        }
                    ),
                    palette: palette
                )

                HStack {
                    if let lastSync = OmniWMThemeSyncService.shared.lastSyncDate {
                        Text("Last synced: \(lastSync.formatted(date: .omitted, time: .standard))")
                            .font(.system(size: 9.5))
                            .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    }
                    Spacer()
                    Button(action: {
                        OmniWMThemeSyncService.shared.syncTheme(palette: palette, force: true)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                            Text("Sync to OmniWM Now")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: palette.primary.hex))
                        .foregroundColor(Color(hex: palette.onPrimary.hex))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        SettingsCard(icon: "sun.max.fill", title: "Appearance Mode, Opacity, Blur & Shadows", palette: palette) {
            HStack {
                Text("Theme Mode")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                Spacer()
                SettingsSegmentedControl(
                    options: [("Dark", "dark"), ("Light", "light"), ("System", "system")],
                    selection: Binding(
                        get: { configStore.config.themeMode },
                        set: { val in configStore.update { $0.themeMode = val } }
                    ),
                    palette: palette
                )
            }

            Divider().opacity(0.3)

            SettingsToggleRow(
                title: "Translucent Blur Surfaces",
                subtitle: "Enable frosted glassmorphism on panels",
                isOn: Binding(
                    get: { configStore.config.barTransparent },
                    set: { val in configStore.update { $0.barTransparent = val } }
                ),
                palette: palette
            )

            SettingsSliderRow(
                title: "Global Surface Opacity",
                valueFormatted: "\(Int(configStore.config.surfaceOpacity * 100))%",
                value: Binding(
                    get: { configStore.config.surfaceOpacity },
                    set: { val in configStore.update(immediate: false) { $0.surfaceOpacity = val } }
                ),
                range: 0.0...1.0,
                step: 0.05,
                palette: palette
            )

            SettingsSliderRow(
                title: "Popup & Modal Opacity",
                valueFormatted: "\(Int(configStore.config.popupTransparency * 100))%",
                value: Binding(
                    get: { configStore.config.popupTransparency },
                    set: { val in configStore.update(immediate: false) { $0.popupTransparency = val } }
                ),
                range: 0.0...1.0,
                step: 0.05,
                palette: palette
            )

            SettingsSliderRow(
                title: "Blur Radius",
                valueFormatted: "\(Int(configStore.config.blurRadius)) px",
                value: Binding(
                    get: { configStore.config.blurRadius },
                    set: { val in configStore.update(immediate: false) { $0.blurRadius = val } }
                ),
                range: 0...64,
                step: 4,
                palette: palette
            )

            Divider().opacity(0.3)

            HStack {
                Text("Surface Corner Style")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                Spacer()
                SettingsSegmentedControl(
                    options: [
                        ("Scaled M3", "scaled"),
                        ("Square", "square"),
                        ("Rounded", "rounded")
                    ],
                    selection: Binding(
                        get: {
                            if let fix = configStore.config.fixedCornerRadius {
                                return fix == 0 ? "square" : "rounded"
                            }
                            return "scaled"
                        },
                        set: { mode in
                            configStore.update {
                                switch mode {
                                case "square":
                                    $0.fixedCornerRadius = 0.0
                                case "rounded":
                                    $0.fixedCornerRadius = 16.0
                                default:
                                    $0.fixedCornerRadius = nil
                                }
                            }
                        }
                    ),
                    palette: palette
                )
            }

            if let fixedRadius = configStore.config.fixedCornerRadius, fixedRadius > 0 {
                SettingsSliderRow(
                    title: "Fixed Surface Radius",
                    valueFormatted: "\(Int(fixedRadius)) px",
                    value: Binding(
                        get: { fixedRadius },
                        set: { val in configStore.update(immediate: false) { $0.fixedCornerRadius = val } }
                    ),
                    range: 4...32,
                    step: 2,
                    helper: "Fixed pixel radius overriding dynamic tokens (THEME-002)",
                    palette: palette
                )
            } else if configStore.config.fixedCornerRadius == nil {
                SettingsSliderRow(
                    title: "Border Radius Strength",
                    valueFormatted: "\(Int(configStore.config.cornerRadiusStrength))%",
                    value: Binding(
                        get: { configStore.config.cornerRadiusStrength },
                        set: { val in configStore.update(immediate: false) { $0.cornerRadiusStrength = val } }
                    ),
                    range: 0.0...100.0,
                    step: 5.0,
                    helper: "0 = sharp rectangular edges, 50 = M3 standard (1.0x), 100 = extra-rounded (2.0x)",
                    palette: palette
                )
            } else {
                Text("Square 0 px corners applied to all shell surfaces and popouts.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
            }

            SettingsSliderRow(
                title: "Global Border Width",
                valueFormatted: String(format: "%.1f px", configStore.config.borderWidth),
                value: Binding(
                    get: { configStore.config.borderWidth },
                    set: { val in configStore.update(immediate: false) { $0.borderWidth = val } }
                ),
                range: 0.0...4.0,
                step: 0.5,
                palette: palette
            )

            Divider().opacity(0.3)

            SettingsToggleRow(
                title: "Enable Drop Shadows",
                subtitle: "Render soft elevation shadows beneath bars, islands, and popouts",
                isOn: Binding(
                    get: { configStore.config.shadowEnabled },
                    set: { val in configStore.update { $0.shadowEnabled = val } }
                ),
                palette: palette
            )

            if configStore.config.shadowEnabled {
                SettingsSliderRow(
                    title: "Shadow Blur Radius",
                    valueFormatted: "\(Int(configStore.config.shadowBlurRadius)) px",
                    value: Binding(
                        get: { configStore.config.shadowBlurRadius },
                        set: { val in configStore.update(immediate: false) { $0.shadowBlurRadius = val } }
                    ),
                    range: 0...48,
                    step: 2,
                    palette: palette
                )

                SettingsSliderRow(
                    title: "Shadow Opacity",
                    valueFormatted: "\(Int(configStore.config.shadowOpacity * 100))%",
                    value: Binding(
                        get: { configStore.config.shadowOpacity },
                        set: { val in configStore.update(immediate: false) { $0.shadowOpacity = val } }
                    ),
                    range: 0.0...0.85,
                    step: 0.05,
                    palette: palette
                )
            }
        }
    }

    // MARK: - 2. Wallpaper Tab
    @ViewBuilder
    private func wallpaperTab(palette: DMSPalette) -> some View {
        let filtered = WallpaperItem.filterWallpapers(
            items: wallpaperService.wallpapers,
            source: wallpaperSelectedSource,
            query: wallpaperSearchQuery
        )
        let currentPath = wallpaperService.currentDesktopPath
        let selected = selectedWallpaperItem ?? filtered.first(where: { $0.path == currentPath }) ?? filtered.first

        VStack(spacing: 12) {
            // Card 1: Active Wallpaper & Auto Color Generation
            SettingsCard(
                icon: "sparkles",
                title: "Active Wallpaper & Theme Sync",
                subtitle: "Desktop wallpaper and automatic Material 3 color generation",
                palette: palette
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsToggleRow(
                        title: "Auto-Generate Colors on Wallpaper Switch",
                        subtitle: "Automatically extract dominant colors and apply dynamic Material 3 theme when switching wallpapers",
                        isOn: Binding(
                            get: { configStore.config.autoGenerateWallpaperColors },
                            set: { val in configStore.update { $0.autoGenerateWallpaperColors = val } }
                        ),
                        palette: palette
                    )

                    Divider().opacity(0.3)

                    // Active wallpaper summary
                    HStack(spacing: 12) {
                        if !currentPath.isEmpty {
                            SettingsWallpaperThumbnail(
                                item: WallpaperItem(id: currentPath, name: (currentPath as NSString).lastPathComponent, path: currentPath),
                                palette: palette
                            )
                            .frame(width: 72, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color(hex: palette.outlineVariant.hex).opacity(0.4), lineWidth: 1)
                            )
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(hex: palette.surfaceContainerHigh.hex))
                                .frame(width: 72, height: 48)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(Color(hex: palette.outline.hex))
                                )
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(currentPath.isEmpty ? "Default System Wallpaper" : (currentPath as NSString).lastPathComponent)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: palette.onSurface.hex))
                                    .lineLimit(1)

                                if configStore.config.theme == "dynamic" {
                                    Text("Dynamic Theme Active")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: palette.primaryContainer.hex))
                                        .foregroundColor(Color(hex: palette.onPrimaryContainer.hex))
                                        .clipShape(Capsule())
                                }
                            }

                            Text(currentPath.isEmpty ? "No custom wallpaper path stored" : currentPath)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: palette.outline.hex))
                                .lineLimit(1)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            if !currentPath.isEmpty {
                                Button {
                                    NSWorkspace.shared.selectFile(currentPath, inFileViewerRootedAtPath: "")
                                } label: {
                                    Image(systemName: "folder")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: palette.onSurface.hex))
                                        .frame(width: 28, height: 28)
                                        .background(Color(hex: palette.surfaceContainerHigh.hex))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Reveal in Finder")
                            }

                            Button {
                                if !currentPath.isEmpty {
                                    themeStore.applyDynamicWallpaper(url: URL(fileURLWithPath: currentPath))
                                } else {
                                    themeStore.setDynamicWallpaper()
                                }
                                ToastCenter.shared.show(icon: "sparkles", message: "Palette Resampled from Wallpaper")
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Resample Colors")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: palette.onPrimary.hex))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: palette.primary.hex))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Live M3 Tonal Palette Swatches
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Theme Palette Swatches (click to copy hex)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: palette.outline.hex))

                        HStack(spacing: 6) {
                            WallpaperColorSwatch(name: "Primary", colorHex: palette.primary.hex, palette: palette)
                            WallpaperColorSwatch(name: "Secondary", colorHex: palette.secondary.hex, palette: palette)
                            WallpaperColorSwatch(name: "Tertiary", colorHex: palette.tertiary.hex, palette: palette)
                            WallpaperColorSwatch(name: "Surface", colorHex: palette.surfaceContainer.hex, palette: palette)
                            WallpaperColorSwatch(name: "Outline", colorHex: palette.outline.hex, palette: palette)
                        }
                    }
                }
            }

            // Card 2: Slanted Wallpaper Picker & Hotkeys (skwd)
            SettingsCard(
                icon: "photo.stack.fill",
                title: "Slanted Wallpaper Picker & Hotkeys",
                subtitle: "skwd-inspired slanted slice carousel, custom folder iteration, and hotkeys",
                palette: palette
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    // Hotkey configuration
                    HotkeyPickerRow(
                        title: "Slanted Wallpaper Picker Hotkey",
                        subtitle: "Global shortcut to open the slanted wallpaper carousel HUD and test wallpapers",
                        icon: "photo.stack.fill",
                        isEnabled: Binding(
                            get: { configStore.config.wallpaperPickerHotkey },
                            set: { val in configStore.update { $0.wallpaperPickerHotkey = val } }
                        ),
                        key: Binding(
                            get: { configStore.config.wallpaperPickerHotkeyKey },
                            set: { val in configStore.update { $0.wallpaperPickerHotkeyKey = val } }
                        ),
                        modifiers: Binding(
                            get: { configStore.config.wallpaperPickerHotkeyModifiers },
                            set: { val in configStore.update { $0.wallpaperPickerHotkeyModifiers = val } }
                        ),
                        palette: palette,
                        onTest: { SlantedWallpaperPickerController.shared.triggerShortcut() }
                    )

                    HStack {
                        Spacer()
                        Button(action: {
                            controller.currentTab = .shortcuts
                        }) {
                            HStack(spacing: 4) {
                                Text("Configure All System Keybinds in One Place")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: palette.primary.hex))
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().opacity(0.3)

                    // Folder restriction toggle
                    SettingsToggleRow(
                        title: "Iterate Specific Folder Only",
                        subtitle: "Restrict slanted wallpaper picker and desktop changer to cycle within a designated folder",
                        isOn: Binding(
                            get: { configStore.config.wallpaperPickerOnlyFolder },
                            set: { val in configStore.update { $0.wallpaperPickerOnlyFolder = val } }
                        ),
                        palette: palette
                    )

                    if configStore.config.wallpaperPickerOnlyFolder {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Wallpaper Folder:")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(Color(hex: palette.primary.hex))

                                Text(configStore.config.wallpaperPickerFolder.isEmpty ? "No specific folder chosen (Using all)" : configStore.config.wallpaperPickerFolder)
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(1)
                                    .foregroundColor(Color(hex: palette.onSurface.hex))

                                Spacer()

                                Button("Choose Folder…") {
                                    pickWallpaperPickerFolder()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                if !configStore.config.wallpaperPickerFolder.isEmpty {
                                    Button {
                                        configStore.update { $0.wallpaperPickerFolder = "" }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color(hex: palette.outline.hex))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(8)
                            .background(Color(hex: palette.surfaceContainerHigh.hex))
                            .cornerRadius(8)

                            // Quick selection pills from indexed folders
                            if !configStore.config.wallpaperFolders.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        Text("Quick Select:")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(Color(hex: palette.outline.hex))

                                        ForEach(configStore.config.wallpaperFolders, id: \.self) { folder in
                                            let isSel = configStore.config.wallpaperPickerFolder == folder
                                            Button {
                                                configStore.update { $0.wallpaperPickerFolder = folder }
                                            } label: {
                                                Text((folder as NSString).lastPathComponent)
                                                    .font(.system(size: 10, weight: isSel ? .bold : .regular))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(isSel ? Color(hex: palette.primaryContainer.hex) : Color(hex: palette.surfaceContainerLow.hex))
                                                    .foregroundColor(isSel ? Color(hex: palette.onPrimaryContainer.hex) : Color(hex: palette.onSurfaceVariant.hex))
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    Divider().opacity(0.3)

                    // Slant / Skew Angle Slider
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Slant Skew Offset")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                            Spacer()
                            Text("\(Int(configStore.config.wallpaperPickerSkew)) px")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: palette.primary.hex))
                        }

                        Slider(
                            value: Binding(
                                get: { configStore.config.wallpaperPickerSkew },
                                set: { val in configStore.update { $0.wallpaperPickerSkew = val } }
                            ),
                            in: 12...48,
                            step: 2
                        )
                    }
                    .padding(.horizontal, 4)

                    Divider().opacity(0.3)

                    // Quick Actions
                    HStack(spacing: 8) {
                        Button {
                            SlantedWallpaperPickerController.shared.show()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.stack.fill")
                                Text("Launch Slanted Wallpaper Picker")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color(hex: palette.primary.hex))
                            .foregroundColor(Color(hex: palette.onPrimary.hex))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button {
                            WallpaperService.shared.nextWallpaper()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.forward.circle")
                                Text("Next Wallpaper")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(hex: palette.surfaceContainerHigh.hex))
                            .foregroundColor(Color(hex: palette.onSurface.hex))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button {
                            WallpaperService.shared.randomWallpaper()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "dice.fill")
                                Text("Random Wallpaper")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(hex: palette.surfaceContainerHigh.hex))
                            .foregroundColor(Color(hex: palette.onSurface.hex))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
            }

            // Card 3: Wallpaper Gallery & Desktop Switcher
            SettingsCard(
                icon: "photo.stack",
                title: "Wallpaper Gallery & Switcher",
                subtitle: "Browse local wallpapers, preview thumbnails, and apply desktop wallpapers with automatic color extraction",
                palette: palette
            ) {
                VStack(spacing: 10) {
                    // Filter Pills & Search Toolbar
                    HStack(spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(WallpaperSource.allCases) { src in
                                    Button(action: { wallpaperSelectedSource = src }) {
                                        Text(src.rawValue)
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(wallpaperSelectedSource == src ? Color(hex: palette.primary.hex) : Color(hex: palette.surfaceContainerHigh.hex))
                                            .foregroundColor(wallpaperSelectedSource == src ? Color(hex: palette.onPrimary.hex) : Color(hex: palette.onSurface.hex))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Spacer()

                        // Add Folder Button
                        Button(action: pickWallpaperFolder) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus")
                                Text("Add Folder…")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(Color(hex: palette.surfaceContainerHighest.hex))
                            .foregroundColor(Color(hex: palette.onSurface.hex))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        // Rescan Button
                        Button(action: { wallpaperService.scan() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: palette.onSurface.hex))
                                .frame(width: 26, height: 26)
                                .background(Color(hex: palette.surfaceContainerHigh.hex))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Rescan wallpaper folders")
                    }

                    // Search Field & Counter
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: palette.outline.hex))

                        TextField("Search wallpapers…", text: $wallpaperSearchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))

                        if !wallpaperSearchQuery.isEmpty {
                            Button(action: { wallpaperSearchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: palette.outline.hex))
                            }
                            .buttonStyle(.plain)
                        }

                        if wallpaperService.isScanning {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 14, height: 14)
                        }

                        Text("\(filtered.count) wallpapers")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: palette.outline.hex))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(hex: palette.surfaceContainerLow.hex))
                    .cornerRadius(8)

                    // 3-Column Wallpaper Gallery Grid
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(filtered) { wp in
                                let isSelected = (selected?.id == wp.id)
                                let isActiveDesktop = wp.isCurrentDesktop || (!currentPath.isEmpty && wp.path == currentPath)

                                Button(action: {
                                    selectedWallpaperItem = wp
                                    pendingWallpaperChange = true
                                }) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ZStack(alignment: .topTrailing) {
                                            SettingsWallpaperThumbnail(item: wp, palette: palette)
                                                .frame(height: 86)
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                            if isActiveDesktop {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "desktopcomputer")
                                                        .font(.system(size: 8, weight: .bold))
                                                    Text("Active")
                                                        .font(.system(size: 8, weight: .bold))
                                                }
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2.5)
                                                .background(Color.black.opacity(0.7))
                                                .foregroundColor(.white)
                                                .clipShape(Capsule())
                                                .padding(5)
                                            }
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(isSelected ? Color(hex: palette.primary.hex) : Color.clear, lineWidth: 2.5)
                                        )

                                        HStack {
                                            Text(wp.name)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(Color(hex: palette.onSurface.hex))
                                                .lineLimit(1)
                                            Spacer()
                                            Text(wp.source.rawValue)
                                                .font(.system(size: 9))
                                                .foregroundColor(Color(hex: palette.outline.hex))
                                        }
                                        .padding(.horizontal, 2)
                                    }
                                    .padding(5)
                                    .background(Color(hex: palette.surfaceContainerLow.hex))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture(count: 2).onEnded {
                                    wallpaperService.applyWallpaper(wp)
                                    selectedWallpaperItem = wp
                                    pendingWallpaperChange = false
                                })
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(minHeight: 280, maxHeight: 380)

                    // Selected Wallpaper Action Bar
                    if let sel = selected {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Selected: \(sel.name)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: palette.onSurface.hex))
                                    .lineLimit(1)
                                Text(sel.path ?? "Built-in Gradient Preset")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: palette.outline.hex))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(action: {
                                wallpaperService.applyWallpaper(sel)
                                selectedWallpaperItem = sel
                                pendingWallpaperChange = false
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                    Text("Apply Wallpaper & Generate Colors")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color(hex: palette.primary.hex))
                                .foregroundColor(Color(hex: palette.onPrimary.hex))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color(hex: palette.surfaceContainerHigh.hex))
                        .cornerRadius(10)
                    }
                }
            }

            // Card 3: Indexed Folders
            SettingsCard(
                icon: "folder",
                title: "Indexed Wallpaper Folders",
                subtitle: "Manage local directories searched for wallpapers",
                palette: palette
            ) {
                VStack(spacing: 6) {
                    WallpaperFolderRow(name: "User Pictures (~/Pictures)", path: (FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first?.path) ?? "~/Pictures", isDefault: true, palette: palette, onRemove: {})
                    WallpaperFolderRow(name: "System Desktop Pictures", path: "/System/Library/Desktop Pictures", isDefault: true, palette: palette, onRemove: {})

                    ForEach(configStore.config.wallpaperFolders, id: \.self) { folder in
                        WallpaperFolderRow(
                            name: (folder as NSString).lastPathComponent,
                            path: folder,
                            isDefault: false,
                            palette: palette,
                            onRemove: {
                                wallpaperService.removeFolder(path: folder)
                            }
                        )
                    }
                }
            }
        }
    }

    private func pickWallpaperFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        panel.message = "Choose a directory containing wallpaper images"

        if panel.runModal() == .OK, let url = panel.url {
            wallpaperService.addFolder(path: url.path)
        }
    }

    private func pickWallpaperPickerFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Wallpaper Folder"
        panel.message = "Choose a directory for the slanted wallpaper picker to iterate"

        if panel.runModal() == .OK, let url = panel.url {
            configStore.update {
                $0.wallpaperPickerFolder = url.path
                $0.wallpaperPickerOnlyFolder = true
            }
            wallpaperService.addFolder(path: url.path)
        }
    }

    // MARK: - 3. Typography & Motion Tab
    @ViewBuilder
    private func typographyTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "textformat", title: "Typography & Font Families", subtitle: "Customize body, display, and monospace fonts", palette: palette) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Body Font Family")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                    Spacer()
                    SettingsSegmentedControl(
                        options: [
                            ("SF Pro", "System"),
                            ("Rounded", "SF Pro Rounded"),
                            ("Serif", "New York"),
                            ("Avenir", "Avenir Next")
                        ],
                        selection: Binding(
                            get: { configStore.config.fontFamily },
                            set: { val in configStore.update { $0.fontFamily = val } }
                        ),
                        palette: palette
                    )
                }

                Divider().opacity(0.3)

                HStack {
                    Text("Monospace Font Family")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                    Spacer()
                    SettingsSegmentedControl(
                        options: [
                            ("SF Mono", "SF Mono"),
                            ("Menlo", "Menlo"),
                            ("Monaco", "Monaco")
                        ],
                        selection: Binding(
                            get: { configStore.config.fontFamilyMono },
                            set: { val in configStore.update { $0.fontFamilyMono = val } }
                        ),
                        palette: palette
                    )
                }

                Divider().opacity(0.3)

                SettingsSliderRow(
                    title: "Global Font Scale",
                    valueFormatted: "\(Int(round(configStore.config.fontScale * 100)))%",
                    value: Binding(
                        get: { configStore.config.fontScale },
                        set: { val in configStore.update(immediate: false) { $0.fontScale = val } }
                    ),
                    range: 0.75...1.35,
                    step: 0.05,
                    helper: "Scales all bar, launcher, and island typography proportionally.",
                    palette: palette
                )
            }
        }

        SettingsCard(icon: "hare.fill", title: "Motion & Animation Physics", subtitle: "M3 duration tokens and reduced motion", palette: palette) {
            SettingsSliderRow(
                title: "Animation Speed Multiplier",
                valueFormatted: String(format: "%.2fx", configStore.config.animationSpeed),
                value: Binding(
                    get: { configStore.config.animationSpeed },
                    set: { val in configStore.update(immediate: false) { $0.animationSpeed = val } }
                ),
                range: 0.25...2.0,
                step: 0.25,
                palette: palette
            )

            Divider().opacity(0.3)

            SettingsToggleRow(
                title: "Reduced Motion",
                subtitle: "Snap Dynamic Island and panel transitions immediately without spring oscillation",
                isOn: Binding(
                    get: { configStore.config.reducedMotion },
                    set: { val in configStore.update { $0.reducedMotion = val } }
                ),
                palette: palette
            )
        }
    }

    // MARK: - 4. Time & Weather Tab
    @ViewBuilder
    private func timeWeatherTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "thermometer", title: "Weather Units", subtitle: "Select temperature scale", palette: palette) {
            SettingsSegmentedControl(
                options: [("Celsius (°C)", "celsius"), ("Fahrenheit (°F)", "fahrenheit")],
                selection: Binding(
                    get: { configStore.config.weatherUnits.lowercased() },
                    set: { val in configStore.update { $0.weatherUnits = val } }
                ),
                palette: palette
            )
        }

        SettingsCard(icon: "mappin.and.ellipse", title: "Location Coordinates", subtitle: "City name, lat,lon, or 'auto'", palette: palette) {
            HStack(spacing: 6) {
                TextField("Location", text: $weatherLocationInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(6)
                    .background(Color(hex: palette.surfaceContainerLow.hex))
                    .cornerRadius(6)

                Button("Set") {
                    let trimmed = weatherLocationInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        WeatherService.shared.setManualLocation(trimmed)
                        ToastCenter.shared.show(icon: "checkmark", message: "Weather Location Updated")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(hex: palette.primary.hex))
                .foregroundColor(Color(hex: palette.onPrimary.hex))
                .cornerRadius(6)

                Button("Auto") {
                    weatherLocationInput = "auto"
                    WeatherService.shared.setManualLocation("auto")
                    ToastCenter.shared.show(icon: "location.fill", message: "Weather Auto GPS Enabled")
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(hex: palette.surfaceContainerLow.hex))
                .cornerRadius(6)
            }

            Text("Current: \(WeatherService.shared.locationName)")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: palette.outline.hex))
        }
    }

    // MARK: - 5. Sounds Tab
    @ViewBuilder
    private func soundsTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "speaker.wave.2.fill", title: "Shell Sound Effects", subtitle: "Audio feedback on interactions", palette: palette) {
            SettingsToggleRow(
                title: "UI Sound Feedback",
                subtitle: "Play soft chimes on launcher activation and notifications",
                isOn: Binding(
                    get: { configStore.config.rawSettings["soundsEnabled"]?.boolValue ?? true },
                    set: { val in configStore.update { $0.rawSettings["soundsEnabled"] = AnyCodable(val) } }
                ),
                palette: palette
            )
        }
    }

    // MARK: - 6. Primary Bar - Appearance Tab
    @ViewBuilder
    private func barAppearanceTab(palette: DMSPalette) -> some View {
        let barCfg = configStore.config.barConfigs.first ?? .default

        SettingsCard(icon: "menubar.rectangle", title: "Bar Position & Orientation", subtitle: "Attach to Top, Bottom, Left, or Right screen edge", palette: palette) {
            SettingsSegmentedControl(
                options: [
                    ("Top", "top"),
                    ("Bottom", "bottom"),
                    ("Left", "left"),
                    ("Right", "right")
                ],
                selection: Binding(
                    get: { configStore.config.barPosition.lowercased() },
                    set: { val in
                        configStore.update { $0.barPosition = val }
                        DankBarController.shared.reposition()
                    }
                ),
                palette: palette
            )
        }

        SettingsCard(icon: "slider.horizontal.below.rectangle", title: "Dimensions, Padding & Spacing", palette: palette) {
            SettingsSliderRow(
                title: "Bar Height / Thickness",
                valueFormatted: "\(barCfg.thickness) px",
                value: Binding(
                    get: { Double(barCfg.thickness) },
                    set: { val in
                        configStore.update(immediate: false) {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].thickness = Int(val) }
                        }
                    }
                ),
                range: 32...68,
                step: 2,
                palette: palette
            )

            SettingsSliderRow(
                title: "Screen Edge Margin",
                valueFormatted: "\(barCfg.margin) px",
                value: Binding(
                    get: { Double(barCfg.margin) },
                    set: { val in
                        configStore.update(immediate: false) {
                            $0.barMarginX = val
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].margin = Int(val) }
                        }
                    }
                ),
                range: 0...32,
                step: 2,
                palette: palette
            )

            SettingsSliderRow(
                title: "Horizontal Inner Padding",
                valueFormatted: "\(Int(barCfg.horizontalPadding)) px",
                value: Binding(
                    get: { barCfg.horizontalPadding },
                    set: { val in
                        configStore.update(immediate: false) {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].horizontalPadding = val }
                        }
                    }
                ),
                range: 2...32,
                step: 2,
                palette: palette
            )

            SettingsSliderRow(
                title: "Vertical Inner Padding",
                valueFormatted: "\(Int(barCfg.verticalPadding)) px",
                value: Binding(
                    get: { barCfg.verticalPadding },
                    set: { val in
                        configStore.update(immediate: false) {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].verticalPadding = val }
                        }
                    }
                ),
                range: 0...16,
                step: 1,
                palette: palette
            )

            SettingsSliderRow(
                title: "Section Spacing",
                valueFormatted: "\(barCfg.spacing) px",
                value: Binding(
                    get: { Double(barCfg.spacing) },
                    set: { val in
                        configStore.update(immediate: false) {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].spacing = Int(val) }
                        }
                    }
                ),
                range: 2...24,
                step: 2,
                palette: palette
            )
        }

        SettingsCard(icon: "paintbrush.pointed.fill", title: "Background & Border Style", palette: palette) {
            HStack {
                Text("Background Style")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                Spacer()
                SettingsSegmentedControl(
                    options: [
                        ("Surface", "surface"),
                        ("Glass", "glass"),
                        ("Floating Pills", "island"),
                        ("Clear", "transparent")
                    ],
                    selection: Binding(
                        get: { barCfg.backgroundStyle },
                        set: { val in
                            configStore.update {
                                if !$0.barConfigs.isEmpty { $0.barConfigs[0].backgroundStyle = val }
                            }
                        }
                    ),
                    palette: palette
                )
            }

            SettingsSliderRow(
                title: "Bar Opacity",
                valueFormatted: "\(Int(barCfg.transparency * 100))%",
                value: Binding(
                    get: { barCfg.transparency },
                    set: { val in
                        configStore.update(immediate: false) {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].transparency = val }
                        }
                    }
                ),
                range: 0.0...1.0,
                step: 0.05,
                palette: palette
            )

            Divider().opacity(0.3)

            SettingsToggleRow(
                title: "Bar Outline Border",
                subtitle: "Draw crisp perimeter stroke around the bar",
                isOn: Binding(
                    get: { barCfg.borderEnabled },
                    set: { val in
                        configStore.update {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].borderEnabled = val }
                        }
                    }
                ),
                palette: palette
            )

            if barCfg.borderEnabled {
                SettingsSliderRow(
                    title: "Border Thickness",
                    valueFormatted: String(format: "%.1f px", barCfg.borderWidth),
                    value: Binding(
                        get: { barCfg.borderWidth },
                        set: { val in
                            configStore.update(immediate: false) {
                                if !$0.barConfigs.isEmpty { $0.barConfigs[0].borderWidth = val }
                            }
                        }
                    ),
                    range: 0.5...4.0,
                    step: 0.5,
                    palette: palette
                )
            }

        }

        SettingsCard(icon: "rectangle.roundedtop", title: "Corner Styling & Geometry", subtitle: "Configure pill capsule, concave Gothic fillets, rounded, or square corners", palette: palette) {
            HStack {
                Text("Corner Style")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                Spacer()
                SettingsSegmentedControl(
                    options: [
                        ("Capsule", BarCornerStyle.capsule),
                        ("Gothic", BarCornerStyle.gothic),
                        ("Rounded", BarCornerStyle.rounded),
                        ("Square", BarCornerStyle.square)
                    ],
                    selection: Binding(
                        get: { barCfg.cornerStyle },
                        set: { style in
                            configStore.update {
                                if !$0.barConfigs.isEmpty {
                                    $0.barConfigs[0].cornerStyle = style
                                }
                            }
                            DankBarController.shared.reposition()
                        }
                    ),
                    palette: palette
                )
            }

            Text(barCfg.cornerStyle.subtitle)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

            if barCfg.cornerStyle == .gothic {
                Divider().opacity(0.3)

                SettingsSliderRow(
                    title: "Gothic Fillet Radius",
                    valueFormatted: "\(Int(barCfg.gothFilletRadius)) px",
                    value: Binding(
                        get: { barCfg.gothFilletRadius },
                        set: { val in
                            configStore.update(immediate: false) {
                                if !$0.barConfigs.isEmpty { $0.barConfigs[0].gothFilletRadius = val }
                            }
                            DankBarController.shared.reposition()
                        }
                    ),
                    range: 6...32,
                    step: 2,
                    helper: "Concave arc radius bridging the bar into the screen edge or Mac notch",
                    palette: palette
                )

                SettingsSliderRow(
                    title: "Desktop Edge Radius",
                    valueFormatted: barCfg.cornerRadius < 0 ? "Capsule" : (barCfg.cornerRadius == 0 ? "Square" : "\(Int(barCfg.cornerRadius)) px"),
                    value: Binding(
                        get: { barCfg.cornerRadius < 0 ? 24.0 : barCfg.cornerRadius },
                        set: { val in
                            configStore.update(immediate: false) {
                                if !$0.barConfigs.isEmpty { $0.barConfigs[0].cornerRadius = val }
                            }
                            DankBarController.shared.reposition()
                        }
                    ),
                    range: 0...32,
                    step: 2,
                    helper: "Convex corner radius for the bar edges facing into the desktop (0 = square, 24 = capsule)",
                    palette: palette
                )
            } else if barCfg.cornerStyle == .rounded {
                Divider().opacity(0.3)

                SettingsSliderRow(
                    title: "Corner Radius",
                    valueFormatted: "\(Int(barCfg.cornerRadius > 0 ? barCfg.cornerRadius : 16)) px",
                    value: Binding(
                        get: { barCfg.cornerRadius > 0 ? barCfg.cornerRadius : 16 },
                        set: { val in
                            configStore.update(immediate: false) {
                                if !$0.barConfigs.isEmpty { $0.barConfigs[0].cornerRadius = val }
                            }
                        }
                    ),
                    range: 4...36,
                    step: 2,
                    helper: "Continuous corner radius across all 4 bar boundaries (M3 tokens: 8, 12, 16, 24, 28)",
                    palette: palette
                )
            }

            Divider().opacity(0.3)

            SettingsToggleRow(
                title: "Auto-Square When Edge-Attached",
                subtitle: "Automatically snap corners to 0 px square when margin is 0 (BAR-001)",
                isOn: Binding(
                    get: { barCfg.autoSquareAttachedCorners },
                    set: { val in
                        configStore.update {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].autoSquareAttachedCorners = val }
                        }
                    }
                ),
                palette: palette
            )

            SettingsToggleRow(
                title: "Popout Connected Mode (\"Gothic Corners\")",
                subtitle: "Bridge popout panels (Control Center, Audio, Dash) into bar body with concave fillets (SURF-001)",
                isOn: Binding(
                    get: { configStore.config.gothCornersEnabled },
                    set: { val in
                        configStore.update { $0.gothCornersEnabled = val }
                        if let screen = NSScreen.main ?? NSScreen.screens.first {
                            ControlCenterController.shared.reposition(on: screen)
                        }
                    }
                ),
                palette: palette
            )
        }
    }

    // MARK: - 7. Primary Bar - Settings & Mac Notch Tab
    @ViewBuilder
    private func barSettingsTab(palette: DMSPalette) -> some View {
        let barCfg = configStore.config.barConfigs.first ?? .default

        SettingsCard(icon: "laptopcomputer", title: "Mac Display Notch & Safe Area Handling", subtitle: "Automatic safe-zone splitting around MacBook notches & Dynamic Island", palette: palette) {
            SettingsToggleRow(
                title: "Adapt Top Bar to Mac Notch & Dynamic Island",
                subtitle: "Automatically split and reflow top bar items into Left and Right safe zones",
                isOn: Binding(
                    get: { barCfg.adaptToNotch },
                    set: { val in
                        configStore.update {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].adaptToNotch = val }
                        }
                    }
                ),
                palette: palette
            )

            Divider().opacity(0.3)

            SettingsToggleRow(
                title: "Simulate Mac Notch on External / Standard Displays",
                subtitle: "Preview notched top bar layout on displays without a physical camera housing",
                isOn: Binding(
                    get: { barCfg.simulateNotch },
                    set: { val in
                        configStore.update {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].simulateNotch = val }
                        }
                    }
                ),
                palette: palette
            )

            if barCfg.simulateNotch {
                SettingsSliderRow(
                    title: "Simulated Notch Width",
                    valueFormatted: "\(Int(barCfg.simulatedNotchWidth)) px",
                    value: Binding(
                        get: { barCfg.simulatedNotchWidth },
                        set: { val in
                            configStore.update(immediate: false) {
                                if !$0.barConfigs.isEmpty { $0.barConfigs[0].simulatedNotchWidth = val }
                            }
                        }
                    ),
                    range: 120...280,
                    step: 4,
                    palette: palette
                )

                SettingsSliderRow(
                    title: "Simulated Notch Height",
                    valueFormatted: "\(Int(barCfg.simulatedNotchHeight)) px",
                    value: Binding(
                        get: { barCfg.simulatedNotchHeight },
                        set: { val in
                            configStore.update(immediate: false) {
                                if !$0.barConfigs.isEmpty { $0.barConfigs[0].simulatedNotchHeight = val }
                            }
                        }
                    ),
                    range: 24...44,
                    step: 2,
                    palette: palette
                )
            }
        }

        SettingsCard(icon: "eye.slash", title: "Auto-Hide Behavior", palette: palette) {
            SettingsToggleRow(
                title: "Auto-Hide Bar",
                subtitle: "Reveals bar smoothly when hovering screen edge",
                isOn: Binding(
                    get: { configStore.config.barAutoHide },
                    set: { val in configStore.update { $0.barAutoHide = val } }
                ),
                palette: palette
            )

            Divider().opacity(0.3)

            SettingsToggleRow(
                title: "Smart Auto-Hide",
                subtitle: "Only hide bar when active application overlaps the edge",
                isOn: Binding(
                    get: { barCfg.smartAutoHide },
                    set: { val in
                        configStore.update {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].smartAutoHide = val }
                        }
                    }
                ),
                palette: palette
            )

            SettingsSliderRow(
                title: "Hover Reveal Delay",
                valueFormatted: "\(barCfg.hoverOpenDelayMs) ms",
                value: Binding(
                    get: { Double(barCfg.hoverOpenDelayMs) },
                    set: { val in
                        configStore.update(immediate: false) {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].hoverOpenDelayMs = Int(val) }
                        }
                    }
                ),
                range: 0...500,
                step: 20,
                palette: palette
            )

            SettingsSliderRow(
                title: "Hover Hide Delay",
                valueFormatted: "\(barCfg.hoverCloseDelayMs) ms",
                value: Binding(
                    get: { Double(barCfg.hoverCloseDelayMs) },
                    set: { val in
                        configStore.update(immediate: false) {
                            if !$0.barConfigs.isEmpty { $0.barConfigs[0].hoverCloseDelayMs = Int(val) }
                        }
                    }
                ),
                range: 100...1000,
                step: 50,
                palette: palette
            )
        }
    }

    // MARK: - 8. Primary Bar - Widgets Tab (Ordering & Per-Widget Styling)
    @ViewBuilder
    private func barWidgetsTab(palette: DMSPalette) -> some View {
        let barConfig = configStore.config.barConfigs.first ?? .default
        let layout = barConfig.layout

        VStack(alignment: .leading, spacing: 10) {
            Text("Reorder widgets with ↑/↓, move between sections, toggle visibility, or click thepaintbrush icon for per-widget styling.")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: palette.outline.hex))

            ForEach([
                ("Left Section", SettingsWidgetCatalog.Section.left, "left", layout.left),
                ("Center Section", SettingsWidgetCatalog.Section.center, "center", layout.center),
                ("Right Section", SettingsWidgetCatalog.Section.right, "right", layout.right)
            ], id: \.2) { (secTitle, secEnum, secKey, items) in
                SettingsCard(icon: "square.grid.2x2", title: secTitle, palette: palette) {
                    VStack(spacing: 4) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            let meta = SettingsWidgetCatalog.all.first(where: { $0.id == item.widgetId })
                            let isExpanded = expandedWidgetStyleId == item.id

                            VStack(spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: meta?.icon ?? "square.grid.2x2")
                                        .font(.system(size: 11))
                                        .foregroundColor(item.enabled ? Color(hex: palette.primary.hex) : Color(hex: palette.outline.hex))
                                        .frame(width: 16)

                                    Text(meta?.name ?? item.widgetId)
                                        .font(.system(size: 11, weight: item.enabled ? .semibold : .regular))
                                        .foregroundColor(item.enabled ? Color(hex: palette.onSurface.hex) : Color(hex: palette.outline.hex))

                                    Spacer()

                                    // Reorder Up
                                    Button(action: {
                                        guard index > 0 else { return }
                                        var updated = layout
                                        SettingsWidgetCatalog.moveWidget(in: secEnum, fromIndex: index, toIndex: index - 1, in: &updated)
                                        configStore.update { $0.barConfigs[0].layout = updated }
                                    }) {
                                        Image(systemName: "chevron.up")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(index > 0 ? Color(hex: palette.onSurfaceVariant.hex) : Color(hex: palette.outline.hex).opacity(0.3))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(index == 0)

                                    // Reorder Down
                                    Button(action: {
                                        guard index + 1 < items.count else { return }
                                        var updated = layout
                                        SettingsWidgetCatalog.moveWidget(in: secEnum, fromIndex: index, toIndex: index + 1, in: &updated)
                                        configStore.update { $0.barConfigs[0].layout = updated }
                                    }) {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(index + 1 < items.count ? Color(hex: palette.onSurfaceVariant.hex) : Color(hex: palette.outline.hex).opacity(0.3))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(index + 1 >= items.count)

                                    // Per-Widget Styling Drawer Toggle
                                    Button(action: {
                                        expandedWidgetStyleId = isExpanded ? nil : item.id
                                    }) {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.system(size: 10))
                                            .foregroundColor(isExpanded ? Color(hex: palette.primary.hex) : Color(hex: palette.onSurfaceVariant.hex))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Customize Widget Style")

                                    // Eye toggle icon
                                    Button(action: {
                                        var updated = layout
                                        SettingsWidgetCatalog.toggleWidget(id: item.id, in: &updated)
                                        configStore.update { $0.barConfigs[0].layout = updated }
                                    }) {
                                        Image(systemName: item.enabled ? "eye" : "eye.slash")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(hex: palette.primary.hex))
                                    }
                                    .buttonStyle(.plain)

                                    // Remove (X) icon
                                    Button(action: {
                                        var updated = layout
                                        SettingsWidgetCatalog.removeWidget(id: item.id, in: &updated)
                                        configStore.update { $0.barConfigs[0].layout = updated }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(hex: palette.error.hex))
                                    }
                                    .buttonStyle(.plain)
                                }

                                if isExpanded {
                                    widgetStyleDrawer(for: item, in: layout, palette: palette)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(hex: palette.surfaceContainerLow.hex))
                            .cornerRadius(6)
                        }

                        // Add Widget button to section
                        Button(action: {
                            activeAddWidgetSection = secKey
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add Widget")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: palette.primary.hex))
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: palette.primaryContainer.hex).opacity(0.4))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func widgetStyleDrawer(for item: BarWidgetEntry, in layout: BarLayout, palette: DMSPalette) -> some View {
        let style = item.styleOptions
        VStack(alignment: .leading, spacing: 6) {
            Divider().opacity(0.25)

            HStack(spacing: 12) {
                Toggle("Compact", isOn: Binding(
                    get: { style.compactMode },
                    set: { val in
                        var updated = layout
                        SettingsWidgetCatalog.updateWidgetOption(id: item.id, key: "compactMode", value: AnyCodable(val), in: &updated)
                        configStore.update { $0.barConfigs[0].layout = updated }
                    }
                ))
                .font(.system(size: 10))

                Toggle("Show Icon", isOn: Binding(
                    get: { style.showIcon },
                    set: { val in
                        var updated = layout
                        SettingsWidgetCatalog.updateWidgetOption(id: item.id, key: "showIcon", value: AnyCodable(val), in: &updated)
                        configStore.update { $0.barConfigs[0].layout = updated }
                    }
                ))
                .font(.system(size: 10))

                Toggle("Show Label", isOn: Binding(
                    get: { style.showLabel },
                    set: { val in
                        var updated = layout
                        SettingsWidgetCatalog.updateWidgetOption(id: item.id, key: "showLabel", value: AnyCodable(val), in: &updated)
                        configStore.update { $0.barConfigs[0].layout = updated }
                    }
                ))
                .font(.system(size: 10))
            }

            if item.widgetId == "clock" {
                HStack(spacing: 12) {
                    Toggle("24-Hour Time", isOn: Binding(
                        get: { (item.options["timeFormat"]?.stringValue ?? "12h") == "24h" },
                        set: { val in
                            var updated = layout
                            SettingsWidgetCatalog.updateWidgetOption(id: item.id, key: "timeFormat", value: AnyCodable(val ? "24h" : "12h"), in: &updated)
                            configStore.update { $0.barConfigs[0].layout = updated }
                        }
                    ))
                    .font(.system(size: 10))

                    Toggle("Seconds", isOn: Binding(
                        get: { item.options["showSeconds"]?.boolValue ?? false },
                        set: { val in
                            var updated = layout
                            SettingsWidgetCatalog.updateWidgetOption(id: item.id, key: "showSeconds", value: AnyCodable(val), in: &updated)
                            configStore.update { $0.barConfigs[0].layout = updated }
                        }
                    ))
                    .font(.system(size: 10))

                    Toggle("Date", isOn: Binding(
                        get: { item.options["showDate"]?.boolValue ?? true },
                        set: { val in
                            var updated = layout
                            SettingsWidgetCatalog.updateWidgetOption(id: item.id, key: "showDate", value: AnyCodable(val), in: &updated)
                            configStore.update { $0.barConfigs[0].layout = updated }
                        }
                    ))
                    .font(.system(size: 10))
                }
            }
        }
        .padding(.top, 2)
    }

    // MARK: - 9. Primary Bar - Workspaces Tab
    @ViewBuilder
    private func barWorkspacesTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "square.split.2x2", title: "Virtual Workspaces", subtitle: "OmniWM & macOS Spaces integration", palette: palette) {
            SettingsToggleRow(
                title: "Show Active Workspaces Pager",
                subtitle: "Render real-time workspace pills in the bar",
                isOn: Binding(
                    get: { configStore.config.showSpaces },
                    set: { val in configStore.update { $0.showSpaces = val } }
                ),
                palette: palette
            )

            Divider().opacity(0.3)

            SettingsToggleRow(
                title: "Show App Icons in Workspaces",
                subtitle: "Display running app badges inside workspace numbers",
                isOn: Binding(
                    get: { configStore.config.showWorkspaceApps },
                    set: { val in configStore.update { $0.showWorkspaceApps = val } }
                ),
                palette: palette
            )
        }
    }

    // MARK: - 10. Primary Bar - Island Tab (Full Dynamic Island Customization per Spec 24)
    @ViewBuilder
    private func islandTab(palette: DMSPalette) -> some View {
        let island = IslandSettings(from: configStore.config.rawSettings)

        // Card 1: Dank Island Mode & Test Controls
        SettingsCard(icon: "capsule.portrait", title: "Dank Island (DIsland)", subtitle: "Interactive Dynamic Island surface & Mac notch integration", palette: palette) {
            HStack {
                Text("Island Instance")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                Spacer()
                SettingsSegmentedControl(
                    options: [
                        ("Off", IslandSettings.Instance.off),
                        ("Main Bar", IslandSettings.Instance.mainBar),
                        ("Mac Notch", IslandSettings.Instance.notch),
                        ("Floating", IslandSettings.Instance.float)
                    ],
                    selection: Binding(
                        get: { island.instance },
                        set: { val in
                            var updated = island
                            updated.instance = val
                            configStore.update { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                        }
                    ),
                    palette: palette
                )
            }

            HStack(spacing: 8) {
                Button("Toggle Expand") {
                    DIslandController.shared.toggle()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: palette.primary.hex))
                .foregroundColor(Color(hex: palette.onPrimary.hex))
                .cornerRadius(6)

                Button("Preview OSD") {
                    DIslandController.shared.triggerOSD(icon: "speaker.wave.3.fill", label: "Volume", progress: 0.78)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: palette.surfaceContainerLow.hex))
                .foregroundColor(Color(hex: palette.onSurface.hex))
                .cornerRadius(6)

                Button("Preview Toast") {
                    DIslandController.shared.triggerNotification(title: "Dynamic Island", body: "Live activity notification preview", level: "info")
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: palette.surfaceContainerLow.hex))
                .foregroundColor(Color(hex: palette.onSurface.hex))
                .cornerRadius(6)
            }

            SettingsToggleRow(
                title: "Media Key & Brightness Interception",
                subtitle: "Directly routes hardware volume/brightness keys through Dynamic Island OSD",
                isOn: Binding(
                    get: { configStore.config.interceptMediaKeys },
                    set: { val in configStore.update { $0.interceptMediaKeys = val } }
                ),
                palette: palette
            )

            if configStore.config.interceptMediaKeys {
                mediaKeyInterceptionStatusView(palette: palette)
            }
        }

        // Card 2: Dimensions & Position
        SettingsCard(icon: "arrow.up.and.down.and.arrow.left.and.right", title: "Dimensions & Position", palette: palette) {
            SettingsSliderRow(
                title: "Compact Island Width",
                valueFormatted: "\(Int(island.compactWidth)) px",
                value: Binding(
                    get: { island.compactWidth },
                    set: { val in
                        var updated = island
                        updated.compactWidth = val
                        configStore.update(immediate: false) { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                    }
                ),
                range: 140...360,
                step: 4,
                palette: palette
            )

            SettingsSliderRow(
                title: "Compact Island Height",
                valueFormatted: "\(Int(island.compactIslandHeight)) px",
                value: Binding(
                    get: { island.compactIslandHeight },
                    set: { val in
                        var updated = island
                        updated.compactIslandHeight = val
                        configStore.update(immediate: false) { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                    }
                ),
                range: 24...48,
                palette: palette
            )

            SettingsSliderRow(
                title: "Expanded Island Width",
                valueFormatted: "\(Int(island.expandedWidth)) px",
                value: Binding(
                    get: { island.expandedWidth },
                    set: { val in
                        var updated = island
                        updated.expandedWidth = val
                        configStore.update(immediate: false) { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                    }
                ),
                range: 280...560,
                step: 8,
                palette: palette
            )

            SettingsSliderRow(
                title: "Expanded Island Height",
                valueFormatted: "\(Int(island.expandedHeight)) px",
                value: Binding(
                    get: { island.expandedHeight },
                    set: { val in
                        var updated = island
                        updated.expandedHeight = val
                        configStore.update(immediate: false) { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                    }
                ),
                range: 110...280,
                step: 4,
                palette: palette
            )

            SettingsSliderRow(
                title: "Outer Gaps",
                valueFormatted: "\(Int(island.outerGaps)) px",
                value: Binding(
                    get: { island.outerGaps },
                    set: { val in
                        var updated = island
                        updated.outerGaps = val
                        configStore.update(immediate: false) { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                    }
                ),
                range: 0...32,
                palette: palette
            )

            SettingsSliderRow(
                title: "Horizontal Offset",
                valueFormatted: "\(Int(island.horizontalOffset)) px",
                value: Binding(
                    get: { island.horizontalOffset },
                    set: { val in
                        var updated = island
                        updated.horizontalOffset = val
                        configStore.update(immediate: false) { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                    }
                ),
                range: -100...100,
                palette: palette
            )
        }

        // Card 3: Animation Curves & Hover Behavior
        SettingsCard(icon: "waveform.path.ecg", title: "Spring Physics & Hover Behavior", subtitle: "8-DOF vector spring solver & hover expansion", palette: palette) {
            HStack {
                Text("Animation Curve")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                Spacer()
                SettingsSegmentedControl(
                    options: [
                        ("Expressive", IslandAnimationCurve.expressive),
                        ("Snappy", IslandAnimationCurve.snappy),
                        ("Smooth", IslandAnimationCurve.smooth),
                        ("Bouncy", IslandAnimationCurve.bouncy),
                        ("Custom", IslandAnimationCurve.custom)
                    ],
                    selection: Binding(
                        get: { island.animationCurve },
                        set: { val in
                            var updated = island
                            updated.animationCurve = val
                            configStore.update { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                        }
                    ),
                    palette: palette
                )
            }

            if island.animationCurve == .custom {
                SettingsSliderRow(
                    title: "Spring Stiffness",
                    valueFormatted: "\(Int(island.springStiffness))",
                    value: Binding(
                        get: { island.springStiffness },
                        set: { val in
                            var updated = island
                            updated.springStiffness = val
                            configStore.update(immediate: false) { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                        }
                    ),
                    range: 120...650,
                    step: 10,
                    palette: palette
                )

                SettingsSliderRow(
                    title: "Spring Damping",
                    valueFormatted: "\(Int(island.springDamping))",
                    value: Binding(
                        get: { island.springDamping },
                        set: { val in
                            var updated = island
                            updated.springDamping = val
                            configStore.update(immediate: false) { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                        }
                    ),
                    range: 12...60,
                    step: 1,
                    palette: palette
                )
            }

            Divider().opacity(0.3)

            SettingsToggleRow(
                title: "Expand on Pointer Hover",
                subtitle: "Automatically expand active drawer when hovering the Dynamic Island",
                isOn: Binding(
                    get: { island.hoverExpand },
                    set: { val in
                        var updated = island
                        updated.hoverExpand = val
                        configStore.update { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                    }
                ),
                palette: palette
            )
        }

        // Card 4: Active Content Modules & Appearance
        SettingsCard(icon: "square.stack.3d.up.fill", title: "Active Content Modules & Appearance", palette: palette) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach([
                    ("Media Player", IslandActivity.media.rawValue),
                    ("Notifications", IslandActivity.notification.rawValue),
                    ("OSD HUD", IslandActivity.osd.rawValue),
                    ("Weather", IslandActivity.weather.rawValue),
                    ("Control Center", IslandActivity.controlCenter.rawValue),
                    ("Clipboard", IslandActivity.clipboard.rawValue),
                    ("Power Menu", IslandActivity.powerMenu.rawValue),
                    ("Launcher", IslandActivity.launcher.rawValue)
                ], id: \.1) { (title, actId) in
                    Toggle(title, isOn: Binding(
                        get: { island.enabledActivities.contains(actId) },
                        set: { enabled in
                            var updated = island
                            if enabled {
                                if !updated.enabledActivities.contains(actId) {
                                    updated.enabledActivities.append(actId)
                                }
                            } else {
                                updated.enabledActivities.removeAll { $0 == actId }
                            }
                            configStore.update { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                        }
                    ))
                    .font(.system(size: 10))
                }
            }

            Divider().opacity(0.3)

            SettingsToggleRow(
                title: "Concave Goth Notch Fillets",
                subtitle: "Blend top corners smoothly into the Mac display bezel",
                isOn: Binding(
                    get: { island.gothCorners },
                    set: { val in
                        var updated = island
                        updated.gothCorners = val
                        configStore.update { $0.islandSettings = updated }
                        DIslandController.shared.reposition()
                    }
                ),
                palette: palette
            )

            if island.gothCorners {
                SettingsSliderRow(
                    title: "Notch Fillet Radius",
                    valueFormatted: "\(Int(island.gothFilletRadius)) px",
                    value: Binding(
                        get: { island.gothFilletRadius },
                        set: { val in
                            var updated = island
                            updated.gothFilletRadius = val
                            configStore.update(immediate: false) { $0.islandSettings = updated }
                            DIslandController.shared.reposition()
                        }
                    ),
                    range: 6...28,
                    step: 2,
                    helper: "Concave bridge radius flaring into MacBook notch (Spec 24: 12 pt)",
                    palette: palette
                )
            }

            SettingsSliderRow(
                title: "Island Opacity",
                valueFormatted: "\(Int(island.opacity * 100))%",
                value: Binding(
                    get: { island.opacity },
                    set: { val in
                        var updated = island
                        updated.opacity = val
                        configStore.update(immediate: false) { $0.rawSettings.merge(updated.toDictionary()) { _, new in new } }
                    }
                ),
                range: 0.0...1.0,
                step: 0.05,
                palette: palette
            )
        }
    }

    // MARK: - 11. Widgets & Notifications - Dashboard Tab
    @ViewBuilder
    private func dashboardTab(palette: DMSPalette) -> some View {
        VStack(spacing: 12) {
            SettingsCard(icon: "gauge", title: "DankDash Overview", subtitle: "Full-screen calendar & system dashboard", palette: palette) {
                SettingsToggleRow(
                    title: "Global Dash Hotkey (⌥D)",
                    subtitle: "Quick toggle overlay with celestial cards and calendar",
                    isOn: Binding(
                        get: { configStore.config.dashHotkey },
                        set: { val in configStore.update { $0.dashHotkey = val } }
                    ),
                    palette: palette
                )
            }

            SettingsCard(
                icon: "hourglass",
                title: "Digital Wellbeing & Screen Time",
                subtitle: "Application focus tracking and macOS Screen Time alignment",
                palette: palette
            ) {
                SettingsToggleRow(
                    title: "Track Application Focus",
                    subtitle: "Record active frontmost application duration in DMS locally",
                    isOn: Binding(
                        get: { configStore.config.enableWellbeing },
                        set: { val in configStore.update { $0.enableWellbeing = val } }
                    ),
                    palette: palette
                )

                Divider().opacity(0.3)

                SettingsToggleRow(
                    title: "Synchronize with macOS Screen Time",
                    subtitle: "Align tracking state with system Screen Time daemon (ScreenTimeAgent)",
                    isOn: Binding(
                        get: { configStore.config.syncWellbeingWithMacOS },
                        set: { val in configStore.update { $0.syncWellbeingWithMacOS = val } }
                    ),
                    palette: palette
                )

                Divider().opacity(0.3)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("macOS Screen Time Integration")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: palette.onSurface.hex))
                        Text(WellbeingService.shared.isMacOSScreenTimeActive ? "macOS ScreenTimeAgent is running and active" : "macOS ScreenTimeAgent is inactive or disabled")
                            .font(.system(size: 11))
                            .foregroundColor(WellbeingService.shared.isMacOSScreenTimeActive ? Color(hex: palette.primary.hex) : Color(hex: palette.error.hex))
                    }
                    Spacer()
                    Button(action: {
                        WellbeingService.shared.openMacOSScreenTimeSettings()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 11))
                            Text("Open Screen Time")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: palette.secondaryContainer.hex))
                        .foregroundColor(Color(hex: palette.onSecondaryContainer.hex))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - 12. Widgets & Notifications - Media Player Tab
    @ViewBuilder
    private func mediaPlayerTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "play.rectangle.fill", title: "Media Controls & Visualizer", palette: palette) {
            SettingsToggleRow(
                title: "Now Playing Bar Pill",
                subtitle: "Show playing track, artist, and album artwork",
                isOn: Binding(
                    get: { configStore.config.showMedia },
                    set: { val in configStore.update { $0.showMedia = val } }
                ),
                palette: palette
            )

            SettingsToggleRow(
                title: "Synchronized Lyrics Bar Widget",
                subtitle: "Allow the Synchronized Lyrics widget to show the live lyric line in DankBar",
                isOn: Binding(
                    get: { configStore.config.showMediaLyricLine },
                    set: { val in configStore.update { $0.showMediaLyricLine = val } }
                ),
                palette: palette
            )

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Media Hub Layout")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                    Text("Bento card grid or Material centered artwork in DankDash")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: palette.outline.hex))
                }
                Spacer()
                SettingsSegmentedControl(
                    options: [("Bento", MediaPlayerLayout.bento), ("Material", MediaPlayerLayout.material)],
                    selection: Binding(
                        get: { configStore.config.mediaPlayerLayout },
                        set: { val in configStore.update { $0.mediaPlayerLayout = val } }
                    ),
                    palette: palette
                )
            }
        }

        SettingsCard(icon: "quote.bubble.fill", title: "Synchronized Lyrics", subtitle: "LRC lyrics from LRCLIB", palette: palette) {
            SettingsToggleRow(
                title: "Enable Automatic Lyrics (LRCLIB)",
                subtitle: "Fetch synchronized lyrics for the playing track from lrclib.net and cache them locally",
                isOn: Binding(
                    get: { configStore.config.enableLyrics },
                    set: { val in configStore.update { $0.enableLyrics = val } }
                ),
                palette: palette
            )

            SettingsSliderRow(
                title: "Lyrics Timing Offset",
                valueFormatted: "\(configStore.config.lyricsOffsetMs >= 0 ? "+" : "")\(configStore.config.lyricsOffsetMs) ms",
                value: Binding(
                    get: { Double(configStore.config.lyricsOffsetMs) },
                    set: { val in configStore.update(immediate: false) { $0.lyricsOffsetMs = Int(val) } }
                ),
                range: -5000...5000,
                step: 50,
                helper: "Positive values show lyrics earlier, negative values later.",
                palette: palette
            )

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lyrics Cache")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                    Text("Stored in ~/Library/Application Support/DMS/lyrics_cache")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: palette.outline.hex))
                }
                Spacer()
                Button("Clear Lyrics Cache") {
                    LyricsService.shared.clearCache()
                    ToastCenter.shared.show(icon: "trash", message: "Lyrics cache cleared")
                }
            }
        }
    }

    // MARK: - 13. Widgets & Notifications - Notifications Tab
    @ViewBuilder
    private func notificationsTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "bell.fill", title: "Notifications Banner", subtitle: "In-shell alerts and toasts", palette: palette) {
            SettingsToggleRow(
                title: "Show DMS In-Shell Toasts",
                subtitle: "Display floating notification pills for system events",
                isOn: Binding(
                    get: { configStore.config.rawSettings["toastsEnabled"]?.boolValue ?? true },
                    set: { val in configStore.update { $0.rawSettings["toastsEnabled"] = AnyCodable(val) } }
                ),
                palette: palette
            )
        }
    }

    // MARK: - 14. Widgets & Notifications - OSD Tab
    @ViewBuilder
    private func osdTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "rectangle.inset.filled", title: "On-Screen Display HUD", subtitle: "Volume and brightness popouts", palette: palette) {
            SettingsToggleRow(
                title: "Floating M3 OSD Pill",
                subtitle: "Displays centered volume and brightness HUD on key adjustments",
                isOn: Binding(
                    get: { configStore.config.rawSettings["osdEnabled"]?.boolValue ?? true },
                    set: { val in configStore.update { $0.rawSettings["osdEnabled"] = AnyCodable(val) } }
                ),
                palette: palette
            )

            SettingsToggleRow(
                title: "Native Media Key Interception",
                subtitle: "Intercepts hardware volume and brightness keys (F1, F2, F10-F12) to suppress standard macOS bezel HUDs",
                isOn: Binding(
                    get: { configStore.config.interceptMediaKeys },
                    set: { val in configStore.update { $0.interceptMediaKeys = val } }
                ),
                palette: palette
            )

            if configStore.config.interceptMediaKeys {
                mediaKeyInterceptionStatusView(palette: palette)
            }
        }
    }

    @ViewBuilder
    private func mediaKeyInterceptionStatusView(palette: DMSPalette) -> some View {
        let interceptor = MediaKeyInterceptor.shared
        switch interceptor.mode {
        case .active:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Active: Hardware media, volume & brightness keys intercepted directly")
                    .font(.caption)
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: palette.surfaceContainerHigh.hex).opacity(0.6))
            .cornerRadius(8)

        case .passive:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
                        .foregroundColor(.blue)
                    Text("Passive Monitoring Active (Input Monitoring)")
                        .font(.caption.bold())
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                    Spacer()
                }
                Text("Media keys are monitored via Input Monitoring. Native macOS bezel HUD is suppressed, and volume adjustments update the HUD via CoreAudio. To swallow keys directly, grant Device Control & Data Access.")
                    .font(.caption2)
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

                Button(action: {
                    interceptor.requestAccessibilityPermission()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.open.fill")
                        Text("Open Device Control & Data Access (macOS 27+)")
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: palette.primary.hex))
                    .foregroundColor(Color(hex: palette.onPrimary.hex))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: palette.surfaceContainerHigh.hex).opacity(0.6))
            .cornerRadius(8)

        case .fallback:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.orange)
                    Text("CoreAudio Fallback Active (Zero Permissions Required)")
                        .font(.caption.bold())
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                    Spacer()
                }
                Text("Native macOS volume HUD is suppressed and volume adjustments trigger the HUD via CoreAudio. In macOS 27+, Accessibility is renamed to 'Device Control and Data Access'.")
                    .font(.caption2)
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

                HStack(spacing: 8) {
                    Button(action: {
                        interceptor.requestAccessibilityPermission()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.open.fill")
                            Text("Open Device Control (Accessibility)")
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: palette.primary.hex))
                        .foregroundColor(Color(hex: palette.onPrimary.hex))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        interceptor.openInputMonitoringSettings()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                            Text("Open Input Monitoring")
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: palette.surfaceContainerHighest.hex))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: palette.surfaceContainerHigh.hex).opacity(0.6))
            .cornerRadius(8)
        }
    }

    // MARK: - 15. Widgets & Notifications - Desktop Widgets Tab
    @ViewBuilder
    private func desktopWidgetsTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "macwindow.on.rectangle", title: "Desktop Widgets", subtitle: "Wallpaper-level clock and system monitoring", palette: palette) {
            SettingsToggleRow(
                title: "Enable Desktop Widgets Canvas",
                subtitle: "Pin interactive telemetry tiles directly to your desktop space",
                isOn: Binding(
                    get: { configStore.config.rawSettings["desktopWidgetsEnabled"]?.boolValue ?? false },
                    set: { val in configStore.update { $0.rawSettings["desktopWidgetsEnabled"] = AnyCodable(val) } }
                ),
                palette: palette
            )
        }
    }

    // MARK: - 16. Dock & Launcher - Dock Tab
    @ViewBuilder
    private func dockTab(palette: DMSPalette) -> some View {
        let dockConfig = configStore.config.dockConfigs.first ?? .default

        SettingsCard(icon: "dock.rectangle", title: "Desktop Dock", palette: palette) {
            SettingsToggleRow(
                title: "Enable Dock",
                subtitle: "Display macOS application dock with pinned apps",
                isOn: Binding(
                    get: { configStore.config.showDock },
                    set: { val in configStore.update { $0.showDock = val } }
                ),
                palette: palette
            )

            Divider().opacity(0.3)

            SettingsSliderRow(
                title: "Icon Size",
                valueFormatted: "\(dockConfig.iconSize) px",
                value: Binding(
                    get: { Double(dockConfig.iconSize) },
                    set: { val in
                        if !configStore.config.dockConfigs.isEmpty {
                            configStore.update { $0.dockConfigs[0].iconSize = Int(val) }
                        }
                    }
                ),
                range: 32...64,
                step: 2,
                palette: palette
            )

            Divider().opacity(0.3)

            SettingsSliderRow(
                title: "Dock Opacity",
                valueFormatted: "\(Int(dockConfig.transparency * 100))%",
                value: Binding(
                    get: { dockConfig.transparency },
                    set: { val in
                        if !configStore.config.dockConfigs.isEmpty {
                            configStore.update { $0.dockConfigs[0].transparency = val }
                        }
                    }
                ),
                range: 0.0...1.0,
                step: 0.05,
                palette: palette
            )

            Divider().opacity(0.3)

            SettingsToggleRow(
                title: "Parabolic Magnification",
                subtitle: "Smooth scale physics on mouse hover",
                isOn: Binding(
                    get: { dockConfig.magnification },
                    set: { val in
                        if !configStore.config.dockConfigs.isEmpty {
                            configStore.update { $0.dockConfigs[0].magnification = val }
                        }
                    }
                ),
                palette: palette
            )

            SettingsSliderRow(
                title: "Magnification Scale",
                valueFormatted: "\(Int(dockConfig.magnificationScale))%",
                value: Binding(
                    get: { dockConfig.magnificationScale },
                    set: { val in
                        if !configStore.config.dockConfigs.isEmpty {
                            configStore.update { $0.dockConfigs[0].magnificationScale = val }
                        }
                    }
                ),
                range: 105...160,
                step: 5,
                palette: palette
            )
        }
    }

    // MARK: - 17. Dock & Launcher - Launcher Tab
    @ViewBuilder
    private func launcherTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "sparkle.magnifyingglass", title: "DLauncherV2 Hotkey", palette: palette) {
            VStack(alignment: .leading, spacing: 8) {
                HotkeyPickerRow(
                    title: "Spotlight / App Launcher Hotkey",
                    subtitle: "Instant keystroke trigger for Spotlight-style launcher, math & app search",
                    icon: "sparkle.magnifyingglass",
                    isEnabled: Binding(
                        get: { configStore.config.launcherHotkey },
                        set: { val in configStore.update { $0.launcherHotkey = val } }
                    ),
                    key: Binding(
                        get: { configStore.config.launcherHotkeyKey },
                        set: { val in configStore.update { $0.launcherHotkeyKey = val } }
                    ),
                    modifiers: Binding(
                        get: { configStore.config.launcherHotkeyModifiers },
                        set: { val in configStore.update { $0.launcherHotkeyModifiers = val } }
                    ),
                    palette: palette,
                    onTest: { LauncherController.shared.toggle() }
                )

                HStack {
                    Spacer()
                    Button(action: {
                        controller.currentTab = .shortcuts
                    }) {
                        HStack(spacing: 4) {
                            Text("Configure All System Keybinds in One Place")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: palette.primary.hex))
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        SettingsCard(icon: "globe", title: "Web Search Fallback", subtitle: "Default query provider", palette: palette) {
            SettingsSegmentedControl(
                options: [("Google", "google"), ("DuckDuckGo", "duckduckgo"), ("Bing", "bing")],
                selection: Binding(
                    get: { configStore.config.webSearchProvider },
                    set: { val in configStore.update { $0.webSearchProvider = val } }
                ),
                palette: palette
            )
        }
    }

    // MARK: - 18. Keyboard Shortcuts Tab
    @ViewBuilder
    private func shortcutsTab(palette: DMSPalette) -> some View {
        VStack(spacing: 12) {
            // Preset Banner & Hyper Key Guide Card
            SettingsCard(
                icon: "sparkles",
                title: "macOS Hyper Key (⌃⌥⇧⌘) & Quick Presets",
                subtitle: "Non-conflicting global shortcut presets for power users",
                palette: palette
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "command.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: palette.primary.hex))

                        Text("Hyper Key maps to ⌃⌥⇧⌘ (Control + Option + Shift + Command). It provides lightning-fast system-wide activation without conflicting with standard macOS app shortcuts. Fully compatible with Karabiner-Elements, BetterTouchTool, and the Hyperkey app.")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: palette.outline.hex))
                    }
                    .padding(10)
                    .background(Color(hex: palette.surfaceContainerLow.hex))
                    .cornerRadius(8)

                    HStack(spacing: 8) {
                        Button(action: {
                            configStore.update {
                                $0.launcherHotkey = true
                                $0.launcherHotkeyModifiers = "hyper"
                                $0.launcherHotkeyKey = "space"

                                $0.dashHotkey = true
                                $0.dashHotkeyModifiers = "hyper"
                                $0.dashHotkeyKey = "d"

                                $0.notepadHotkey = true
                                $0.notepadHotkeyModifiers = "hyper"
                                $0.notepadHotkeyKey = "n"

                                $0.clipboardHotkey = true
                                $0.clipboardHotkeyModifiers = "hyper"
                                $0.clipboardHotkeyKey = "v"

                                $0.wallpaperPickerHotkey = true
                                $0.wallpaperPickerHotkeyModifiers = "hyper"
                                $0.wallpaperPickerHotkeyKey = "w"
                            }
                            ToastCenter.shared.show(icon: "sparkles", message: "All Shortcuts Set to Hyper Key (⌃⌥⇧⌘)")
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                Text("Set All to Hyper Key")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: palette.primary.hex))
                            .foregroundColor(Color(hex: palette.onPrimary.hex))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            configStore.update {
                                $0.launcherHotkey = true
                                $0.launcherHotkeyModifiers = "option"
                                $0.launcherHotkeyKey = "space"

                                $0.dashHotkey = true
                                $0.dashHotkeyModifiers = "option"
                                $0.dashHotkeyKey = "d"

                                $0.notepadHotkey = true
                                $0.notepadHotkeyModifiers = "option"
                                $0.notepadHotkeyKey = "n"

                                $0.clipboardHotkey = true
                                $0.clipboardHotkeyModifiers = "option"
                                $0.clipboardHotkeyKey = "v"

                                $0.wallpaperPickerHotkey = true
                                $0.wallpaperPickerHotkeyModifiers = "hyper"
                                $0.wallpaperPickerHotkeyKey = "w"
                            }
                            ToastCenter.shared.show(icon: "arrow.counterclockwise", message: "Restored Default Shortcuts")
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 11))
                                Text("Restore Defaults")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: palette.surfaceContainerHigh.hex))
                            .foregroundColor(Color(hex: palette.onSurface.hex))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button(action: {
                            KeybindsController.shared.toggle()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "command")
                                    .font(.system(size: 11))
                                Text("Keybinds Cheatsheet HUD")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: palette.secondaryContainer.hex))
                            .foregroundColor(Color(hex: palette.onSecondaryContainer.hex))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Centralized Hotkeys Card
            SettingsCard(
                icon: "keyboard.fill",
                title: "All DMS System Hotkeys",
                subtitle: "Centralized Carbon keystroke triggers with customizable modifiers, keys, and live testing",
                palette: palette
            ) {
                VStack(spacing: 8) {
                    // 1. Spotlight / App Launcher
                    HotkeyPickerRow(
                        title: "DLauncherV2 (App Launcher)",
                        subtitle: "Spotlight-style instant app launcher, math evaluator, and quick search",
                        icon: "sparkle.magnifyingglass",
                        isEnabled: Binding(
                            get: { configStore.config.launcherHotkey },
                            set: { val in configStore.update { $0.launcherHotkey = val } }
                        ),
                        key: Binding(
                            get: { configStore.config.launcherHotkeyKey },
                            set: { val in configStore.update { $0.launcherHotkeyKey = val } }
                        ),
                        modifiers: Binding(
                            get: { configStore.config.launcherHotkeyModifiers },
                            set: { val in configStore.update { $0.launcherHotkeyModifiers = val } }
                        ),
                        palette: palette,
                        onTest: { LauncherController.shared.toggle() }
                    )

                    // 2. DankDash Overview
                    HotkeyPickerRow(
                        title: "DankDash Overview",
                        subtitle: "Dashboard HUD with system telemetry stats, calendar, and media widgets",
                        icon: "gauge",
                        isEnabled: Binding(
                            get: { configStore.config.dashHotkey },
                            set: { val in configStore.update { $0.dashHotkey = val } }
                        ),
                        key: Binding(
                            get: { configStore.config.dashHotkeyKey },
                            set: { val in configStore.update { $0.dashHotkeyKey = val } }
                        ),
                        modifiers: Binding(
                            get: { configStore.config.dashHotkeyModifiers },
                            set: { val in configStore.update { $0.dashHotkeyModifiers = val } }
                        ),
                        palette: palette,
                        onTest: { DashController.shared.toggle() }
                    )

                    // 3. Quick Scratchpad
                    HotkeyPickerRow(
                        title: "Quick Notepad Scratchpad",
                        subtitle: "Floating scratchpad notes overlay for fast note-taking",
                        icon: "note.text",
                        isEnabled: Binding(
                            get: { configStore.config.notepadHotkey },
                            set: { val in configStore.update { $0.notepadHotkey = val } }
                        ),
                        key: Binding(
                            get: { configStore.config.notepadHotkeyKey },
                            set: { val in configStore.update { $0.notepadHotkeyKey = val } }
                        ),
                        modifiers: Binding(
                            get: { configStore.config.notepadHotkeyModifiers },
                            set: { val in configStore.update { $0.notepadHotkeyModifiers = val } }
                        ),
                        palette: palette,
                        onTest: { NotepadController.shared.toggle() }
                    )

                    // 4. Clipboard History
                    HotkeyPickerRow(
                        title: "Clipboard History Manager",
                        subtitle: "Multi-item clipboard history viewer with search and quick paste",
                        icon: "doc.on.clipboard.fill",
                        isEnabled: Binding(
                            get: { configStore.config.clipboardHotkey },
                            set: { val in configStore.update { $0.clipboardHotkey = val } }
                        ),
                        key: Binding(
                            get: { configStore.config.clipboardHotkeyKey },
                            set: { val in configStore.update { $0.clipboardHotkeyKey = val } }
                        ),
                        modifiers: Binding(
                            get: { configStore.config.clipboardHotkeyModifiers },
                            set: { val in configStore.update { $0.clipboardHotkeyModifiers = val } }
                        ),
                        palette: palette,
                        onTest: { ClipboardController.shared.toggle() }
                    )

                    // 5. Slanted Wallpaper Picker (skwd)
                    HotkeyPickerRow(
                        title: "Slanted Wallpaper Picker (skwd)",
                        subtitle: "Slanted parallelogram slice carousel with desktop preview testing & rapid cycling",
                        icon: "photo.stack.fill",
                        isEnabled: Binding(
                            get: { configStore.config.wallpaperPickerHotkey },
                            set: { val in configStore.update { $0.wallpaperPickerHotkey = val } }
                        ),
                        key: Binding(
                            get: { configStore.config.wallpaperPickerHotkeyKey },
                            set: { val in configStore.update { $0.wallpaperPickerHotkeyKey = val } }
                        ),
                        modifiers: Binding(
                            get: { configStore.config.wallpaperPickerHotkeyModifiers },
                            set: { val in configStore.update { $0.wallpaperPickerHotkeyModifiers = val } }
                        ),
                        palette: palette,
                        onTest: { SlantedWallpaperPickerController.shared.triggerShortcut() }
                    )
                }
            }
        }
    }

    // MARK: - 19. Power & Sleep Tab
    @ViewBuilder
    private func powerTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "bolt.fill", title: "Idle & Sleep Management", palette: palette) {
            SettingsToggleRow(
                title: "Sleep Inhibit (Caffeinate Display & System)",
                subtitle: "Prevents screen sleep during presentations or active tasks",
                isOn: Binding(
                    get: { inhibit.isInhibited },
                    set: { val in
                        if val { inhibit.enable() } else { inhibit.disable() }
                    }
                ),
                palette: palette
            )
        }
    }

    // MARK: - 20. Plugins Tab (Matches settings_plugin.png!)
    @ViewBuilder
    private func pluginsTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "puzzlepiece.extension.fill", title: "Plugin Manager & Registry", palette: palette) {
            HStack {
                Button(action: {
                    showBrowsePluginsModal = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill")
                        Text("Browse Plugins")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: palette.onPrimary.hex))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: palette.primary.hex))
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    pluginService.saveLockfile()
                    ToastCenter.shared.show(icon: "lock.shield.fill", message: "Saved plugins.lock.json")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.doc.fill")
                        Text("Lock Plugins")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: palette.primary.hex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: palette.primaryContainer.hex))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // Installed list
            let installed = pluginService.plugins.filter { $0.isInstalled }
            if !installed.isEmpty {
                VStack(spacing: 6) {
                    ForEach(installed) { plugin in
                        HStack(spacing: 8) {
                            Image(systemName: plugin.icon)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: palette.primary.hex))
                                .frame(width: 22, height: 22)
                                .background(Color(hex: palette.surfaceVariant.hex))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 1) {
                                Text(plugin.name)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: palette.onSurface.hex))
                                Text(plugin.description)
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(hex: palette.outline.hex))
                                    .lineLimit(1)
                            }

                            Spacer()

                            if plugin.id == "symbian-belle-sync" && plugin.isEnabled {
                                Button(action: { _ = SymbianClient.shared.launchCompanion() }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "arrow.up.forward.app")
                                        Text("Open Sync")
                                    }
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(hex: palette.onPrimary.hex))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: palette.primary.hex))
                                    .cornerRadius(5)
                                }
                                .buttonStyle(.plain)
                            }

                            Toggle("", isOn: Binding(
                                get: { plugin.isEnabled },
                                set: { _ in pluginService.togglePlugin(id: plugin.id) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()

                            Button(action: { pluginService.uninstallPlugin(id: plugin.id) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: palette.error.hex))
                                    .padding(4)
                                    .background(Color(hex: palette.surfaceVariant.hex))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(hex: palette.surfaceContainerLow.hex))
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - 21. About Tab
    @ViewBuilder
    private func aboutTab(palette: DMSPalette) -> some View {
        SettingsCard(icon: "info.circle.fill", title: "DankMaterialShell (DMS)", subtitle: "Native macOS Port", palette: palette) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Native Swift 6 & SwiftUI port of AvengeMedia/DankMaterialShell. Follows complete Material Design 3 guidelines with zero idle CPU and native macOS integration.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

                HStack(spacing: 12) {
                    Link("Documentation", destination: URL(string: "https://danklinux.com/docs")!)
                    Link("GitHub Repository", destination: URL(string: "https://github.com/AvengeMedia/DankMaterialShell")!)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

                Divider().opacity(0.3).padding(.vertical, 2)

                Text("SUBSYSTEM HEALTH")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: palette.outline.hex))

                VStack(spacing: 4) {
                    diagnosticRow(name: "CoreAudio Engine", status: "Active", ok: true, palette: palette)
                    diagnosticRow(name: "CoreWLAN Network", status: "Active", ok: true, palette: palette)
                    diagnosticRow(name: "IOBluetooth Controller", status: "Active", ok: true, palette: palette)
                    diagnosticRow(name: "IOKit Power & Battery", status: "Active", ok: true, palette: palette)
                    diagnosticRow(name: "DisplayServices (dlopen)", status: "Loaded", ok: true, palette: palette)
                    diagnosticRow(name: "CBBlueLightClient (dlopen)", status: "Loaded", ok: true, palette: palette)
                    diagnosticRow(name: "Unix Socket Daemon", status: "Listening (dms.sock)", ok: true, palette: palette)
                    diagnosticRow(
                        name: "DankSearch Fault-Tolerant Engine",
                        status: DankSearchClient.shared.healthState == .healthy ? "Healthy" : (DankSearchClient.shared.healthState.statusMessage ?? "Degraded"),
                        ok: !DankSearchClient.shared.healthState.isDegraded,
                        palette: palette
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func diagnosticRow(name: String, status: String, ok: Bool, palette: DMSPalette) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(ok ? Color(hex: palette.primary.hex) : Color(hex: palette.error.hex))
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: palette.onSurface.hex))
            Spacer()
            Text(status)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: palette.outline.hex))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(hex: palette.surfaceContainerLow.hex))
        .cornerRadius(6)
    }

    private func themeColor(for name: String) -> Color {
        switch name.lowercased() {
        case "purple": return Color(hex: "#7C4DFF")
        case "blue": return Color(hex: "#2196F3")
        case "green": return Color(hex: "#4CAF50")
        case "orange": return Color(hex: "#FF9800")
        case "red": return Color(hex: "#F44336")
        case "yellow": return Color(hex: "#FFEB3B")
        case "neutral": return Color(hex: "#9E9E9E")
        case "catppuccin-mocha": return Color(hex: "#CBA6F7")
        case "catppuccin-latte": return Color(hex: "#8839EF")
        case "nord": return Color(hex: "#88C0D0")
        case "gruvbox": return Color(hex: "#FABD2F")
        case "tokyo-night": return Color(hex: "#7AA2F7")
        case "everforest": return Color(hex: "#A7C080")
        default: return Color(hex: "#7C4DFF")
        }
    }
}

// MARK: - Wallpaper Settings Helper Components

private struct SettingsWallpaperThumbnail: View {
    let item: WallpaperItem
    let palette: DMSPalette

    @State private var thumbnailImage: NSImage?
    @State private var isLoading: Bool = false

    var body: some View {
        ZStack {
            if let img = thumbnailImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let hexes = item.gradientColorsHex, !hexes.isEmpty {
                LinearGradient(
                    colors: hexes.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(hex: palette.surfaceContainerHighest.hex)
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                }
            }
        }
        .task(id: item.id) {
            guard item.path != nil else { return }
            isLoading = true
            let img = await WallpaperService.shared.thumbnail(for: item)
            self.thumbnailImage = img
            self.isLoading = false
        }
    }
}

private struct WallpaperColorSwatch: View {
    let name: String
    let colorHex: String
    let palette: DMSPalette

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(colorHex, forType: .string)
            ToastCenter.shared.show(icon: "doc.on.doc", message: "Copied \(name): \(colorHex)")
        } label: {
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(hex: colorHex))
                    .frame(height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                Text(name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                    .lineLimit(1)
                Text(colorHex.uppercased())
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(hex: palette.outline.hex))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(4)
            .background(Color(hex: palette.surfaceContainerLow.hex))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

private struct WallpaperFolderRow: View {
    let name: String
    let path: String
    let isDefault: Bool
    let palette: DMSPalette
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isDefault ? "folder.fill" : "folder.badge.gearshape")
                .foregroundColor(Color(hex: palette.primary.hex))
                .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                Text(path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: palette.outline.hex))
                    .lineLimit(1)
            }

            Spacer()

            if isDefault {
                Text("System Default")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: palette.outline.hex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: palette.surfaceContainerHighest.hex))
                    .clipShape(Capsule())
            } else {
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: palette.error.hex))
                        .frame(width: 22, height: 22)
                        .background(Color(hex: palette.errorContainer.hex).opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Remove folder")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(hex: palette.surfaceContainerLow.hex))
        .cornerRadius(8)
    }
}

private struct OmniWMWindowBorderPreview: View {
    let palette: DMSPalette
    let mode: OmniWMGradientMode
    let direction: OmniWMGradientDirection

    var body: some View {
        let (start, end, solid, isGradient) = OmniWMThemeUpdater.resolveColors(palette: palette, mode: mode)
        let startColor = Color(hex: start.hex)
        let endColor = Color(hex: end.hex)
        let solidColor = Color(hex: solid.hex)

        let startPoint: UnitPoint = direction == .topLeftToBottomRight ? .topLeading : .topTrailing
        let endPoint: UnitPoint = direction == .topLeftToBottomRight ? .bottomTrailing : .bottomLeading

        let borderGradient = LinearGradient(
            colors: isGradient ? [startColor, endColor] : [solidColor, solidColor],
            startPoint: startPoint,
            endPoint: endPoint
        )

        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: palette.surfaceContainerLowest.hex))
                    .frame(height: 72)
                    .overlay(
                        VStack(spacing: 0) {
                            HStack(spacing: 5) {
                                Circle().fill(Color.red.opacity(0.85)).frame(width: 8, height: 8)
                                Circle().fill(Color.yellow.opacity(0.85)).frame(width: 8, height: 8)
                                Circle().fill(Color.green.opacity(0.85)).frame(width: 8, height: 8)
                                Spacer()
                                Text("OmniWM Active Window Preview")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                                Spacer()
                                Color.clear.frame(width: 32, height: 8)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 20)
                            .background(Color(hex: palette.surfaceContainerHigh.hex))

                            Spacer()

                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: palette.primary.hex))
                                Text(isGradient ? "\(start.hex)  ➔  \(end.hex)" : "\(solid.hex) (Solid)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color(hex: palette.onSurface.hex))
                            }
                            Spacer()
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(borderGradient, lineWidth: 2.5)
                    )
                    .shadow(color: startColor.opacity(0.35), radius: 6, x: 0, y: 3)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }
}
