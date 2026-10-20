import SwiftUI
import AppKit
import DMSCore

/// Dedicated application launcher icon slot for the Desktop Dock.
public struct DockLauncherButton: View {
    public let config: DockConfig
    public let scale: Double
    public let isHovered: Bool

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        config: DockConfig,
        scale: Double = 1.0,
        isHovered: Bool = false
    ) {
        self.config = config
        self.scale = scale
        self.isHovered = isHovered
    }

    private var effectiveIconSize: CGFloat {
        CGFloat(config.iconSize) * CGFloat(scale)
    }

    public var body: some View {
        Button {
            LauncherController.shared.toggle()
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(theme.primaryContainer)
                        .frame(width: effectiveIconSize, height: effectiveIconSize)

                    Image(systemName: "square.grid.2x2.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(theme.onPrimaryContainer)
                        .frame(width: effectiveIconSize * 0.5, height: effectiveIconSize * 0.5)
                }
                .dockHoverBounce(isHovered: isHovered, position: config.position, enabled: true)

                // Bottom spacer matching indicator lane
                Color.clear.frame(width: 4, height: max(4.0, Double(effectiveIconSize) * 0.10))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open Launcher") {
                LauncherController.shared.show()
            }
            Button("DMS Settings") {
                SettingsController.shared.show()
            }
        }
    }
}
