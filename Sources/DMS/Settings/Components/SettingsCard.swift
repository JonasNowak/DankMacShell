import SwiftUI
import DMSCore

/// Material 3 Card container for settings sections.
public struct SettingsCard<Content: View>: View {
    public let icon: String?
    public let title: String?
    public let subtitle: String?
    public let palette: DMSPalette
    public let content: Content

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
        VStack(alignment: .leading, spacing: 10) {
            if let title = title {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: palette.primary.hex))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: palette.onSurface.hex))
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: palette.outline.hex))
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 2)
            }

            content
        }
        .padding(12)
        .background(Color(hex: palette.surfaceContainerHigh.hex))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: palette.outlineVariant.hex).opacity(0.3), lineWidth: 1)
        )
    }
}

/// Material 3 segmented pill selector (e.g., [✓ Left | Right | Hidden] from DMS spec/screenshots).
public struct SettingsSegmentedControl<T: Hashable & Equatable>: View {
    public let options: [(title: String, value: T)]
    @Binding public var selection: T
    public let palette: DMSPalette

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
        HStack(spacing: 4) {
            ForEach(0..<options.count, id: \.self) { idx in
                let item = options[idx]
                let isSelected = selection == item.value

                Button(action: {
                    selection = item.value
                }) {
                    HStack(spacing: 5) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: palette.primary.hex))
                        }
                        Text(item.title)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? Color(hex: palette.onPrimaryContainer.hex) : Color(hex: palette.onSurfaceVariant.hex))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isSelected
                            ? Color(hex: palette.primaryContainer.hex)
                            : Color(hex: palette.surfaceContainerLow.hex).opacity(0.6)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(hex: palette.surfaceContainerLow.hex))
        .cornerRadius(10)
    }
}

/// Material 3 Slider row with title, live value readout, and explanatory subtext.
public struct SettingsSliderRow: View {
    public let title: String
    public let valueFormatted: String
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let step: Double
    public let helper: String?
    public let palette: DMSPalette

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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                Spacer()
                Text(valueFormatted)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: palette.primary.hex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: palette.primaryContainer.hex).opacity(0.5))
                    .cornerRadius(4)
            }

            Slider(value: $value, in: range, step: step)
                .tint(Color(hex: palette.primary.hex))

            if let helper = helper {
                Text(helper)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: palette.outline.hex))
            }
        }
    }
}

/// Material 3 Toggle row with icon, title, description, and switch.
public struct SettingsToggleRow: View {
    public let title: String
    public let subtitle: String?
    @Binding public var isOn: Bool
    public let palette: DMSPalette

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
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: palette.outline.hex))
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}
