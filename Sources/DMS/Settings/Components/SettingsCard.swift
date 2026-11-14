import SwiftUI
import DMSCore
import MaterialMacLibrary

/// Material 3 Card container for settings sections.
/// Chrome is delegated to `MaterialComponents.MaterialSettingsCard` with the bridged
/// `MaterialTheme`; the explicit `palette` parameter is forwarded to the library card.
public struct SettingsCard<Content: View>: View {
    public let icon: String?
    public let title: String?
    public let subtitle: String?
    public let palette: DMSPalette
    public let content: Content

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        icon: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        palette: DMSPalette,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.palette = palette
        self.content = content()
    }

    public var body: some View {
        MaterialSettingsCard(icon: icon, title: title, subtitle: subtitle, palette: palette) {
            content
        }
        .materialTheme(theme.materialTheme)
    }
}

/// Material 3 segmented pill selector (e.g., [✓ Left | Right | Hidden] from DMS spec/screenshots).
/// Delegated to `MaterialComponents.MaterialSegmentedControl`.
public struct SettingsSegmentedControl<T: Hashable & Equatable>: View {
    public let options: [(title: String, value: T)]
    @Binding public var selection: T
    public let palette: DMSPalette

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        options: [(title: String, value: T)],
        selection: Binding<T>,
        palette: DMSPalette
    ) {
        self.options = options
        self._selection = selection
        self.palette = palette
    }

    public var body: some View {
        MaterialSegmentedControl(options: options, selection: $selection, palette: palette)
            .materialTheme(theme.materialTheme)
    }
}

/// Material 3 Slider row with title, live value readout, and explanatory subtext.
/// Delegated to `MaterialComponents.MaterialSliderRow`.
public struct SettingsSliderRow: View {
    public let title: String
    public let valueFormatted: String
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let step: Double
    public let helper: String?
    public let palette: DMSPalette

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        title: String,
        valueFormatted: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1.0,
        helper: String? = nil,
        palette: DMSPalette
    ) {
        self.title = title
        self.valueFormatted = valueFormatted
        self._value = value
        self.range = range
        self.step = step
        self.helper = helper
        self.palette = palette
    }

    public var body: some View {
        MaterialSliderRow(
            title: title,
            valueFormatted: valueFormatted,
            value: $value,
            range: range,
            step: step,
            helper: helper,
            palette: palette
        )
        .materialTheme(theme.materialTheme)
    }
}

/// Material 3 Toggle row with title, description, and switch.
/// Delegated to `MaterialComponents.MaterialToggleRow`.
public struct SettingsToggleRow: View {
    public let title: String
    public let subtitle: String?
    @Binding public var isOn: Bool
    public let palette: DMSPalette

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        palette: DMSPalette
    ) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.palette = palette
    }

    public var body: some View {
        MaterialToggleRow(title: title, subtitle: subtitle, isOn: $isOn, palette: palette)
            .materialTheme(theme.materialTheme)
    }
}
