import SwiftUI
import DMSCore

/// A Material 3 interactive row for configuring a global hotkey shortcut.
/// Displays an icon, title, description, live badge, modifier preset picker, key picker, and an optional test trigger button.
public struct HotkeyPickerRow: View {
    public let title: String
    public let subtitle: String?
    public let icon: String?
    @Binding public var isEnabled: Bool
    @Binding public var key: String
    @Binding public var modifiers: String
    public let palette: DMSPalette
    public var onTest: (() -> Void)? = nil

    @State private var justTriggered: Bool = false

    public init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        isEnabled: Binding<Bool>,
        key: Binding<String>,
        modifiers: Binding<String>,
        palette: DMSPalette,
        onTest: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self._isEnabled = isEnabled
        self._key = key
        self._modifiers = modifiers
        self.palette = palette
        self.onTest = onTest
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row: Icon, Title, Subtitle, Preview Badge, Enable/Disable Toggle
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isEnabled ? Color(hex: palette.primary.hex) : Color(hex: palette.outline.hex))
                        .frame(width: 28, height: 28)
                        .background(
                            isEnabled
                                ? Color(hex: palette.primaryContainer.hex).opacity(0.4)
                                : Color(hex: palette.surfaceContainerHigh.hex)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(isEnabled ? Color(hex: palette.onSurface.hex) : Color(hex: palette.outline.hex))

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 10.5))
                            .foregroundColor(Color(hex: palette.outline.hex))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Active shortcut preview badge
                if isEnabled {
                    Text(HotkeyHelper.displayString(key: key, modifiers: modifiers))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color(hex: palette.primaryContainer.hex))
                        .foregroundColor(Color(hex: palette.onPrimaryContainer.hex))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Text("Disabled")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: palette.surfaceContainerHigh.hex))
                        .foregroundColor(Color(hex: palette.outline.hex))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .tint(Color(hex: palette.primary.hex))
                    .labelsHidden()
            }

            // Expanded pickers when enabled
            if isEnabled {
                Divider().opacity(0.25)

                HStack(spacing: 12) {
                    // Modifier picker
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Modifiers")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

                        Picker("", selection: $modifiers) {
                            ForEach(HotkeyModifierPreset.allCases) { preset in
                                Text(preset.title).tag(preset.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 210)
                    }

                    // Key picker
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Key")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))

                        Picker("", selection: Binding(
                            get: { key.lowercased() },
                            set: { key = $0 }
                        )) {
                            ForEach(HotkeyHelper.standardKeyOptions) { opt in
                                Text(opt.title).tag(opt.tag)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }

                    Spacer()

                    // Test button
                    if let onTest = onTest {
                        Button(action: {
                            onTest()
                            justTriggered = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                justTriggered = false
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: justTriggered ? "checkmark.circle.fill" : "play.fill")
                                    .font(.system(size: 9))
                                Text(justTriggered ? "Triggered" : "Test")
                                    .font(.system(size: 10.5, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                justTriggered
                                    ? Color.green.opacity(0.2)
                                    : Color(hex: palette.surfaceContainerHigh.hex)
                            )
                            .foregroundColor(
                                justTriggered
                                    ? Color.green
                                    : Color(hex: palette.onSurface.hex)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color(hex: palette.outlineVariant.hex).opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Test triggering this hotkey action now")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: palette.surfaceContainerLow.hex).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(hex: palette.outlineVariant.hex).opacity(0.3), lineWidth: 1)
        )
    }
}
