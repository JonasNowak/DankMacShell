import SwiftUI
import DMSCore

/// Primary filesystem storage used/available percentage indicator.
/// Complies with `docs/spec/20-bar-widgets.md` `diskUsage`.
public struct DiskGaugeWidget: View {
    public var isVertical: Bool
    @ObservedObject private var theme = ThemeStore.shared
    @State private var usedPercent: Double = 0.0

    public init(isVertical: Bool = false) {
        self.isVertical = isVertical
    }

    private var diskColor: Color {
        if usedPercent >= 90.0 {
            return theme.error
        } else if usedPercent >= 75.0 {
            return theme.warning
        } else {
            return theme.onSurface
        }
    }

    public var body: some View {
        Button {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Disk Utility.app"))
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(diskColor)

                if !isVertical {
                    Text("\(Int(round(usedPercent)))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(diskColor)
                }
            }
            .padding(.horizontal, isVertical ? 0 : 6)
            .frame(width: isVertical ? 28 : nil, height: isVertical ? 28 : 26)
            .background(theme.surfaceContainerHigh)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Storage used: \(Int(round(usedPercent)))%")
        .onAppear {
            refreshDiskUsage()
        }
    }

    private func refreshDiskUsage() {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let total = attrs[.systemSize] as? NSNumber,
           let free = attrs[.systemFreeSize] as? NSNumber {
            let totalBytes = total.doubleValue
            let freeBytes = free.doubleValue
            if totalBytes > 0 {
                let used = (totalBytes - freeBytes) / totalBytes * 100.0
                self.usedPercent = max(0.0, min(100.0, used))
            }
        }
    }
}
