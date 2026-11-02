import SwiftUI
import IOKit.pwr_mgt
import DMSCore

public struct PowerAssertionItem: Identifiable, Sendable {
    public var id: String { "\(pid)_\(assertionType)_\(assertionName)" }
    public let pid: Int32
    public let processName: String
    public let assertionType: String
    public let assertionName: String
}

/// Detail subpage for Idle Inhibitor (Caffeine) controls and active sleep assertions.
public struct IdleInhibitorDetailPage: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var inhibit = IdleInhibitService.shared
    @State private var activeAssertions: [PowerAssertionItem] = []

    public init() {}

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 12) {
            // Master Caffeine Switch Tile
            HStack(spacing: 10) {
                Image(systemName: inhibit.isInhibited ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 18))
                    .foregroundColor(inhibit.isInhibited ? Color(hex: p.onPrimary.hex) : Color(hex: p.primary.hex))
                    .frame(width: 36, height: 36)
                    .background(inhibit.isInhibited ? Color(hex: p.primary.hex) : Color(hex: p.primaryContainer.hex).opacity(0.4))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep Awake (Caffeine)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: p.onSurface.hex))

                    if inhibit.isInhibited, let secs = inhibit.remainingSeconds {
                        Text("Active • \(IdleInhibitCountdown.formatRemaining(seconds: secs)) remaining")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: p.primary.hex))
                    } else {
                        Text(inhibit.isInhibited ? "Active • Indefinite" : "Prevent display and system sleep")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { inhibit.isInhibited },
                    set: { _ in inhibit.toggle() }
                ))
                .toggleStyle(.switch)
            }
            .padding(12)
            .background(Color(hex: p.surfaceContainerHigh.hex))
            .cornerRadius(14)

            // Countdown Progress Bar (if timed)
            if inhibit.isInhibited, let cd = inhibit.countdown {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Remaining Duration")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        Spacer()
                        if let remaining = inhibit.remainingSeconds {
                            Text(IdleInhibitCountdown.formatRemainingShort(seconds: remaining))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: p.primary.hex))
                        }
                    }

                    GeometryReader { geo in
                        let progress = CGFloat(cd.progress())
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(themeStore.subtleTrackColor)
                            Capsule()
                                .fill(Color(hex: p.primary.hex))
                                .frame(width: geo.size.width * (1.0 - progress))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 4)
            }

            // Duration Presets Grid
            VStack(alignment: .leading, spacing: 6) {
                Text("Timed Duration Presets")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                    .padding(.horizontal, 4)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(IdleInhibitPreset.allCases) { preset in
                        let isSelected = inhibit.isInhibited && inhibit.activePreset == preset

                        Button(action: {
                            inhibit.enable(preset: preset)
                        }) {
                            Text(preset.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSelected ? Color(hex: p.onPrimary.hex) : Color(hex: p.onSurface.hex))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(isSelected ? Color(hex: p.primary.hex) : Color(hex: p.surfaceContainerHigh.hex))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Active Power Assertions
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Active Sleep Assertions")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                    Spacer()
                    Button(action: refreshAssertions) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: p.primary.hex))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)

                if activeAssertions.isEmpty {
                    Text("No external applications are currently preventing sleep.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: p.outline.hex))
                        .padding(.horizontal, 4)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(activeAssertions) { a in
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(a.processName)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color(hex: p.onSurface.hex))
                                        Text(a.assertionType)
                                            .font(.system(size: 8))
                                            .foregroundColor(Color(hex: p.outline.hex))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text("PID \(a.pid)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: p.surfaceContainerHigh.hex))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 90)
                }
            }

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            refreshAssertions()
        }
    }

    private func refreshAssertions() {
        var assertionsByProcess: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&assertionsByProcess) == kIOReturnSuccess,
              let cfDict = assertionsByProcess?.takeRetainedValue(),
              let dict = cfDict as? [NSNumber: [NSDictionary]] else {
            activeAssertions = []
            return
        }

        var items: [PowerAssertionItem] = []
        for (pidNum, list) in dict {
            let pid = pidNum.int32Value
            let app = NSRunningApplication(processIdentifier: pid)
            let name = app?.localizedName ?? "PID \(pid)"

            for item in list {
                let aType = item[kIOPMAssertionTypeKey as String] as? String ?? "UnknownAssertion"
                let aName = item[kIOPMAssertionNameKey as String] as? String ?? ""
                items.append(PowerAssertionItem(
                    pid: pid,
                    processName: name,
                    assertionType: aType,
                    assertionName: aName
                ))
            }
        }
        self.activeAssertions = items
    }
}
