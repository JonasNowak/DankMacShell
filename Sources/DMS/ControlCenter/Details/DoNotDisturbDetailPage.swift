import SwiftUI
import DMSCore

/// Detail subpage for Do Not Disturb / Focus controls.
public struct DoNotDisturbDetailPage: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var dndService = DoNotDisturbService.shared

    public init() {}

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 12) {
            // Master Switch Tile
            HStack(spacing: 10) {
                Image(systemName: dndService.isEnabled ? "bell.slash.fill" : "bell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(dndService.isEnabled ? Color(hex: p.onPrimary.hex) : Color(hex: p.primary.hex))
                    .frame(width: 36, height: 36)
                    .background(dndService.isEnabled ? Color(hex: p.primary.hex) : Color(hex: p.primaryContainer.hex).opacity(0.4))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Do Not Disturb")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: p.onSurface.hex))

                    if dndService.isEnabled, let secs = dndService.remainingSeconds {
                        Text("Active • \(WellbeingFormatter.formatDuration(seconds: secs)) remaining")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: p.primary.hex))
                    } else {
                        Text(dndService.isEnabled ? "Active • Indefinite" : "Silence notifications and alerts")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { dndService.isEnabled },
                    set: { _ in dndService.toggle() }
                ))
                .toggleStyle(.switch)
            }
            .padding(12)
            .background(Color(hex: p.surfaceContainerHigh.hex))
            .cornerRadius(14)

            // Duration Presets
            VStack(alignment: .leading, spacing: 6) {
                Text("Duration Presets")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                    .padding(.horizontal, 4)

                VStack(spacing: 6) {
                    ForEach(DNDPreset.allCases) { preset in
                        let isSelected = dndService.isEnabled && dndService.activePreset == preset

                        Button(action: {
                            dndService.enable(preset: preset)
                        }) {
                            HStack {
                                Text(preset.label)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? Color(hex: p.onPrimary.hex) : Color(hex: p.onSurface.hex))

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(hex: p.onPrimary.hex))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color(hex: p.primary.hex) : Color(hex: p.surfaceContainerHigh.hex))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // Open Focus Settings Link
            Button(action: {
                dndService.openFocusSettings()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                    Text("macOS Focus Settings…")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: p.primary.hex))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(hex: p.surfaceContainerHighest.hex).opacity(0.6))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
