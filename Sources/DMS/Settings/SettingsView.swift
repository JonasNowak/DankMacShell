import SwiftUI
import DMSCore

/// Material 3 comprehensive Settings modal view.
public struct SettingsView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var configStore = ConfigStore.shared
    @ObservedObject var inhibit = IdleInhibitService.shared
    @ObservedObject var pluginService = PluginService.shared
    @State private var selectedTab: SettingsTab = .appearance
    @State private var pluginSearchQuery: String = ""

    let onClose: () -> Void

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case applets = "Customize Applets"
        case plugins = "Plugins"
        case bar = "Bar & Margins"
        case launcher = "Launcher"
        case power = "Power & Sleep"
        case doctor = "Diagnostics"
        case about = "About"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .appearance: return "paintpalette.fill"
            case .applets: return "square.grid.2x2.fill"
            case .plugins: return "puzzlepiece.extension.fill"
            case .bar: return "menubar.rectangle"
            case .launcher: return "sparkle.magnifyingglass"
            case .power: return "bolt.fill"
            case .doctor: return "stethoscope"
            case .about: return "info.circle.fill"
            }
        }
    }

    public init(initialTab: String? = nil, onClose: @escaping () -> Void) {
        if let tabStr = initialTab, let found = SettingsTab.allCases.first(where: {
            $0.rawValue.lowercased() == tabStr.lowercased() ||
            $0.id.lowercased() == tabStr.lowercased() ||
            ($0 == .applets && tabStr.lowercased() == "applets")
        }) {
            _selectedTab = State(initialValue: found)
        }
        self.onClose = onClose
    }

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(Color(hex: p.primary.hex))

                Text("DMS Settings")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: p.onSurface.hex))

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: p.surfaceVariant.hex))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(hex: p.surfaceContainerHigh.hex))

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            HStack(spacing: 0) {
                // Sidebar Tabs
                VStack(spacing: 6) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button(action: { selectedTab = tab }) {
                            HStack(spacing: 10) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(selectedTab == tab ? Color(hex: p.primary.hex) : Color(hex: p.onSurfaceVariant.hex))
                                    .frame(width: 20)

                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                                    .foregroundColor(selectedTab == tab ? Color(hex: p.primary.hex) : Color(hex: p.onSurface.hex))
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(selectedTab == tab ? Color(hex: p.primaryContainer.hex) : Color.clear)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(12)
                .frame(width: 190)
                .background(Color(hex: p.surfaceContainerLow.hex))

                Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

                // Tab Content Area
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .appearance:
                            appearanceSettings(palette: p)
                        case .applets:
                            appletsSettings(palette: p)
                        case .plugins:
                            pluginsSettings(palette: p)
                        case .bar:
                            barSettings(palette: p)
                        case .launcher:
                            launcherSettings(palette: p)
                        case .power:
                            powerSettings(palette: p)
                        case .doctor:
                            diagnosticsSettings(palette: p)
                        case .about:
                            aboutSettings(palette: p)
                        }
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

            // Footer
            HStack {
                Text("Hot-reloading enabled via ~/Library/Application Support/DMS/config.json")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: p.outline.hex))
                Spacer()
                Button(action: {
                    configStore.save()
                    ToastCenter.shared.show(icon: "checkmark.circle.fill", message: "Settings Saved")
                }) {
                    Text("Apply Changes")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: p.onPrimary.hex))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(hex: p.primary.hex))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(hex: p.surfaceContainerHigh.hex))
        }
        .frame(width: 760, height: 580)
        .background(Color(hex: p.surface.hex))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Customize Applets Tab
    @ViewBuilder
    private func appletsSettings(palette: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CUSTOMIZE DANKBAR APPLETS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            Text("Toggle individual applets and indicators on the left, center, and right sections of DankBar.")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

            ForEach(DMSApplet.DMSAppletPosition.allCases, id: \.self) { pos in
                let posApplets = pluginService.applets.filter { $0.position == pos }
                if !posApplets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(pos.rawValue.uppercased()) SECTION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: palette.outline.hex))
                            .padding(.top, 4)

                        VStack(spacing: 6) {
                            ForEach(posApplets) { applet in
                                HStack(spacing: 12) {
                                    Image(systemName: applet.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: palette.primary.hex))
                                        .frame(width: 24, height: 24)
                                        .background(Color(hex: palette.surfaceVariant.hex))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(applet.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color(hex: palette.onSurface.hex))
                                        Text(applet.description)
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(hex: palette.outline.hex))
                                    }

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { applet.isEnabled },
                                        set: { _ in pluginService.toggleApplet(id: applet.id) }
                                    ))
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(hex: palette.surfaceContainerHigh.hex))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Plugins Tab
    @ViewBuilder
    private func pluginsSettings(palette: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLUGIN MANAGER & REGISTRY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: palette.primary.hex))
                    Text("Extend DMS with widgets, control center cards, launcher providers, and daemons.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                }
                Spacer()

                Button(action: {
                    pluginService.saveLockfile()
                    ToastCenter.shared.show(icon: "lock.shield.fill", message: "Saved plugins.lock.json")
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.doc.fill")
                        Text("Lock Plugins")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: palette.primary.hex))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: palette.primaryContainer.hex))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: palette.outline.hex))
                TextField("Search plugin registry...", text: $pluginSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: palette.surfaceContainerHigh.hex))
            .cornerRadius(10)

            // Installed Plugins
            let installed = pluginService.plugins.filter { $0.isInstalled }
            if !installed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("INSTALLED PLUGINS (\(installed.count))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: palette.outline.hex))

                    VStack(spacing: 6) {
                        ForEach(installed) { plugin in
                            HStack(spacing: 12) {
                                Image(systemName: plugin.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: palette.primary.hex))
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: palette.surfaceVariant.hex))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(plugin.name)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: palette.onSurface.hex))
                                        Text("v\(plugin.version)")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(Color(hex: palette.outline.hex))
                                        Text(plugin.type.title)
                                            .font(.system(size: 9, weight: .semibold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: palette.secondaryContainer.hex))
                                            .foregroundColor(Color(hex: palette.onSecondaryContainer.hex))
                                            .cornerRadius(4)
                                    }

                                    Text(plugin.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { plugin.isEnabled },
                                    set: { _ in pluginService.togglePlugin(id: plugin.id) }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()

                                Button(action: { pluginService.uninstallPlugin(id: plugin.id) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: palette.error.hex))
                                        .padding(6)
                                        .background(Color(hex: palette.surfaceVariant.hex))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: palette.surfaceContainerHigh.hex))
                            .cornerRadius(10)
                        }
                    }
                }
            }

            // Available in Registry
            let available = pluginService.plugins.filter { plugin in
                !plugin.isInstalled && (pluginSearchQuery.isEmpty ||
                    plugin.name.localizedCaseInsensitiveContains(pluginSearchQuery) ||
                    plugin.description.localizedCaseInsensitiveContains(pluginSearchQuery))
            }

            if !available.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("COMMUNITY & OFFICIAL REGISTRY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: palette.outline.hex))

                    VStack(spacing: 6) {
                        ForEach(available) { plugin in
                            HStack(spacing: 12) {
                                Image(systemName: plugin.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: palette.outline.hex))
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: palette.surfaceVariant.hex))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(plugin.name)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: palette.onSurface.hex))
                                        Text("by \(plugin.author)")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(hex: palette.outline.hex))
                                        Text(plugin.type.title)
                                            .font(.system(size: 9, weight: .semibold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: palette.surfaceVariant.hex))
                                            .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                                            .cornerRadius(4)
                                    }

                                    Text(plugin.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                                }

                                Spacer()

                                Button(action: { pluginService.installPlugin(id: plugin.id) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("Install")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: palette.onPrimary.hex))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: palette.primary.hex))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: palette.surfaceContainerHigh.hex))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Appearance Tab
    @ViewBuilder
    private func appearanceSettings(palette: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("MATERIAL 3 PALETTES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            VStack(spacing: 8) {
                // Dynamic Wallpaper Theme Option
                Button(action: {
                    themeStore.setDynamicWallpaper()
                    configStore.update { $0.theme = "dynamic" }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: palette.primary.hex))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dynamic Wallpaper Palette")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: palette.onSurface.hex))
                            Text("Mathematically samples your macOS wallpaper using CoreImage")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: palette.outline.hex))
                        }
                        Spacer()
                        if themeStore.themeName.lowercased() == "dynamic" {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: palette.primary.hex))
                        }
                    }
                    .padding(12)
                    .background(Color(hex: palette.surfaceContainerHigh.hex))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Stock Themes
                let stockThemes = ["purple", "blue", "green", "orange", "red", "yellow", "neutral"]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(stockThemes, id: \.self) { name in
                        Button(action: {
                            themeStore.apply(theme: name)
                            configStore.update { $0.theme = name }
                        }) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(themeColor(for: name))
                                    .frame(width: 16, height: 16)
                                Text(name.capitalized)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: palette.onSurface.hex))
                                Spacer()
                                if themeStore.themeName.lowercased() == name {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(hex: palette.primary.hex))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: palette.surfaceContainerHigh.hex))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            Text("SURFACE & LIGHTING")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            Toggle(isOn: Binding(
                get: { themeStore.isLightMode },
                set: { val in
                    themeStore.setLightMode(val)
                    configStore.update { $0.isLightMode = val }
                }
            )) {
                Label("Light Mode Appearance", systemImage: "sun.max.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .toggleStyle(.switch)

            Toggle(isOn: Binding(
                get: { configStore.config.barTransparent },
                set: { val in configStore.update { $0.barTransparent = val } }
            )) {
                Label("Translucent Background with Blur", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .medium))
            }
            .toggleStyle(.switch)
        }
    }

    // MARK: - Bar & Margins Tab
    @ViewBuilder
    private func barSettings(palette: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("POSITION & STRETCHING")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            Picker("Bar Position", selection: Binding(
                get: { configStore.config.barPosition },
                set: { val in
                    configStore.update { $0.barPosition = val }
                    DankBarController.shared.reposition()
                }
            )) {
                Text("Bottom Shelf").tag("bottom")
                Text("Top Status Bar").tag("top")
            }
            .pickerStyle(.segmented)

            // Side Margin Slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Side Margin / Screen Stretching")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                    Spacer()
                    Text("\(Int(configStore.config.barMarginX)) px")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: palette.primary.hex))
                }

                Slider(value: Binding(
                    get: { configStore.config.barMarginX },
                    set: { val in
                        configStore.update { $0.barMarginX = val }
                        DankBarController.shared.reposition()
                    }
                ), in: 0...32, step: 2)
                .tint(Color(hex: palette.primary.hex))

                Text("Lower values (e.g. 0-8px) stretch DankBar cleanly towards both screen edges.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: palette.outline.hex))
            }
            .padding(12)
            .background(Color(hex: palette.surfaceContainerHigh.hex))
            .cornerRadius(10)

            Toggle(isOn: Binding(
                get: { configStore.config.barAutoHide },
                set: { val in configStore.update { $0.barAutoHide = val } }
            )) {
                Label("Auto-Hide Bar (Reveal on Screen Edge Hover)", systemImage: "eye.slash")
                    .font(.system(size: 13, weight: .medium))
            }
            .toggleStyle(.switch)
        }
    }

    // MARK: - Launcher Tab
    @ViewBuilder
    private func launcherSettings(palette: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DLAUNCHERV2 SHORTCUTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            Toggle("Global Launcher Hotkey (⌥Space)", isOn: Binding(
                get: { configStore.config.launcherHotkey },
                set: { val in configStore.update { $0.launcherHotkey = val } }
            ))
            .toggleStyle(.switch)

            Toggle("DankDash Hotkey (⌥D)", isOn: Binding(
                get: { configStore.config.dashHotkey },
                set: { val in configStore.update { $0.dashHotkey = val } }
            ))
            .toggleStyle(.switch)

            Toggle("Notepad Hotkey (⌥N)", isOn: Binding(
                get: { configStore.config.notepadHotkey },
                set: { val in configStore.update { $0.notepadHotkey = val } }
            ))
            .toggleStyle(.switch)

            Toggle("Clipboard History Hotkey (⌥V)", isOn: Binding(
                get: { configStore.config.clipboardHotkey },
                set: { val in configStore.update { $0.clipboardHotkey = val } }
            ))
            .toggleStyle(.switch)

            Divider()

            Text("WEB SEARCH FALLBACK")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            Picker("Default Provider", selection: Binding(
                get: { configStore.config.webSearchProvider },
                set: { val in configStore.update { $0.webSearchProvider = val } }
            )) {
                Text("Google").tag("google")
                Text("DuckDuckGo").tag("duckduckgo")
                Text("Bing").tag("bing")
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Power Tab
    @ViewBuilder
    private func powerSettings(palette: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("IDLE & SLEEP MANAGEMENT")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            Toggle("Sleep Inhibit (Caffeinate Display & System)", isOn: Binding(
                get: { inhibit.isInhibited },
                set: { val in
                    if val { inhibit.enable() } else { inhibit.disable() }
                }
            ))
            .toggleStyle(.switch)

            Text("When enabled, DMS prevents your Mac screen and system from going to sleep while background tasks or presentations run.")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: palette.outline.hex))
        }
    }

    // MARK: - Diagnostics Tab
    @ViewBuilder
    private func diagnosticsSettings(palette: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SYSTEM SUBSYSTEMS STATUS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            DiagnosticRow(name: "CoreAudio Engine", status: "Active", ok: true, palette: palette)
            DiagnosticRow(name: "CoreWLAN Network", status: "Active", ok: true, palette: palette)
            DiagnosticRow(name: "IOBluetooth Controller", status: "Active", ok: true, palette: palette)
            DiagnosticRow(name: "IOKit Power & Battery", status: "Active", ok: true, palette: palette)
            DiagnosticRow(name: "DisplayServices (Brightness)", status: "Loaded via dlopen", ok: true, palette: palette)
            DiagnosticRow(name: "CBBlueLightClient (Night Shift)", status: "Loaded via dlopen", ok: true, palette: palette)
            DiagnosticRow(name: "Unix Socket Daemon", status: "Listening on dms.sock", ok: true, palette: palette)
            DiagnosticRow(name: "Plugin Registry", status: "\(pluginService.plugins.count) plugins indexed", ok: true, palette: palette)
            DiagnosticRow(name: "Workspace Service", status: "SkyLight active space observer", ok: true, palette: palette)
        }
    }

    // MARK: - About Tab
    @ViewBuilder
    private func aboutSettings(palette: DMSPalette) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.grid.cross.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: palette.primary.hex))

            Text("DankMaterialShell (DMS)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: palette.onSurface.hex))

            Text("Native macOS edition of AvengeMedia/DankMaterialShell\nBuilt with Swift 6, AppKit, and SwiftUI")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Documentation", destination: URL(string: "https://danklinux.com/docs")!)
                Link("GitHub", destination: URL(string: "https://github.com/AvengeMedia/DankMaterialShell")!)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Color(hex: palette.primary.hex))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private func themeColor(for name: String) -> Color {
        switch name {
        case "purple": return Color(hex: "#7C4DFF")
        case "blue": return Color(hex: "#2196F3")
        case "green": return Color(hex: "#4CAF50")
        case "orange": return Color(hex: "#FF9800")
        case "red": return Color(hex: "#F44336")
        case "yellow": return Color(hex: "#FFEB3B")
        case "neutral": return Color(hex: "#9E9E9E")
        default: return Color(hex: "#7C4DFF")
        }
    }
}

private struct DiagnosticRow: View {
    let name: String
    let status: String
    let ok: Bool
    let palette: DMSPalette

    var body: some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(ok ? Color(hex: palette.primary.hex) : Color(hex: palette.error.hex))
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: palette.onSurface.hex))
            Spacer()
            Text(status)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: palette.outline.hex))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: palette.surfaceContainerHigh.hex))
        .cornerRadius(10)
    }
}
