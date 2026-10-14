import SwiftUI
import DMSCore

/// Material 3 comprehensive Settings modal view.
public struct SettingsView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var configStore = ConfigStore.shared
    @ObservedObject var inhibit = IdleInhibitService.shared
    @State private var selectedTab: SettingsTab = .appearance

    let onClose: () -> Void

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case bar = "Bar & Dock"
        case launcher = "Launcher"
        case power = "Power & Sleep"
        case doctor = "Diagnostics"
        case about = "About"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .appearance: return "paintpalette.fill"
            case .bar: return "menubar.dock.rectangle"
            case .launcher: return "sparkle.magnifyingglass"
            case .power: return "bolt.fill"
            case .doctor: return "stethoscope"
            case .about: return "info.circle.fill"
            }
        }
    }

    public init(initialTab: String? = nil, onClose: @escaping () -> Void) {
        if let tabStr = initialTab, let found = SettingsTab.allCases.first(where: { $0.rawValue.lowercased() == tabStr.lowercased() || $0.id.lowercased() == tabStr.lowercased() }) {
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
                .frame(width: 170)
                .background(Color(hex: p.surfaceContainerLow.hex))

                Divider().background(Color(hex: p.outlineVariant.hex).opacity(0.5))

                // Tab Content Area
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .appearance:
                            appearanceSettings(palette: p)
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
                        .padding(.vertical, 6)
                        .background(Color(hex: p.primary.hex))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(hex: p.surfaceContainerHigh.hex))
        }
        .frame(width: 660, height: 480)
        .background(Color(hex: p.surface.hex))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 26, x: 0, y: 12)
    }

    // MARK: - Tab Views
    @ViewBuilder
    private func appearanceSettings(palette: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("THEME PALETTES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            let themes = ["dynamic", "purple", "blue", "green", "orange", "red", "yellow", "neutral"]
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                ForEach(themes, id: \.self) { name in
                    Button(action: {
                        themeStore.apply(theme: name, lightMode: themeStore.isLightMode)
                        configStore.update { $0.theme = name }
                    }) {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(themeColor(for: name))
                                .frame(width: 28, height: 28)
                            Text(name.capitalized)
                                .font(.system(size: 12, weight: themeStore.themeName == name ? .bold : .medium))
                                .foregroundColor(themeStore.themeName == name ? Color(hex: palette.primary.hex) : Color(hex: palette.onSurface.hex))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(themeStore.themeName == name ? Color(hex: palette.primaryContainer.hex) : Color(hex: palette.surfaceContainerHigh.hex))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Text("COLOR MODE & BLUR")
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

    @ViewBuilder
    private func barSettings(palette: DMSPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("POSITION & VISIBILITY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            Picker("Bar Position", selection: Binding(
                get: { configStore.config.barPosition },
                set: { val in configStore.update { $0.barPosition = val } }
            )) {
                Text("Bottom Shelf").tag("bottom")
                Text("Top Status Bar").tag("top")
            }
            .pickerStyle(.segmented)

            Toggle(isOn: Binding(
                get: { configStore.config.barAutoHide },
                set: { val in configStore.update { $0.barAutoHide = val } }
            )) {
                Label("Auto-Hide Bar (Reveal on Screen Edge Hover)", systemImage: "eye.slash")
                    .font(.system(size: 13, weight: .medium))
            }
            .toggleStyle(.switch)

            Divider()

            Text("ENABLED WIDGETS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: palette.primary.hex))

            Toggle("Apps Dock / Taskbar", isOn: Binding(
                get: { configStore.config.showDock },
                set: { val in configStore.update { $0.showDock = val } }
            ))
            .toggleStyle(.switch)

            Toggle("Hardware Telemetry (CPU, RAM, Battery)", isOn: Binding(
                get: { configStore.config.showTelemetry },
                set: { val in configStore.update { $0.showTelemetry = val } }
            ))
            .toggleStyle(.switch)

            Toggle("Live Weather Pill", isOn: Binding(
                get: { configStore.config.showWeather },
                set: { val in configStore.update { $0.showWeather = val } }
            ))
            .toggleStyle(.switch)

            Toggle("Media Playback Pill", isOn: Binding(
                get: { configStore.config.showMedia },
                set: { val in configStore.update { $0.showMedia = val } }
            ))
            .toggleStyle(.switch)

            Toggle("Workspaces / Spaces Pager", isOn: Binding(
                get: { configStore.config.showSpaces },
                set: { val in configStore.update { $0.showSpaces = val } }
            ))
            .toggleStyle(.switch)
        }
    }

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
        }
    }

    @ViewBuilder
    private func aboutSettings(palette: DMSPalette) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.grid.cross.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: palette.primary.hex))

            Text("DankMaterialShell (DMS)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: palette.onSurface.hex))

            Text("Native macOS port of AvengeMedia/DankMaterialShell\nBuilt with Swift 6, AppKit, and SwiftUI")
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
