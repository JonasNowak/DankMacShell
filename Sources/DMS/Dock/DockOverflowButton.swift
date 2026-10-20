import SwiftUI
import AppKit
import DMSCore

/// Dynamic chevron overflow button shown when pinned and running apps exceed maxVisibleApps.
public struct DockOverflowButton: View {
    public let hiddenApps: [AppItem]
    public let config: DockConfig
    public let scale: Double
    public let isHovered: Bool

    @ObservedObject private var theme = ThemeStore.shared
    @State private var isShowingPopover = false

    public init(
        hiddenApps: [AppItem],
        config: DockConfig,
        scale: Double = 1.0,
        isHovered: Bool = false
    ) {
        self.hiddenApps = hiddenApps
        self.config = config
        self.scale = scale
        self.isHovered = isHovered
    }

    private var effectiveIconSize: CGFloat {
        CGFloat(config.iconSize) * CGFloat(scale)
    }

    public var body: some View {
        Button {
            isShowingPopover.toggle()
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(theme.surfaceContainerHigh)
                        .frame(width: effectiveIconSize, height: effectiveIconSize)

                    Image(systemName: "chevron.right.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(theme.primary)
                        .frame(width: effectiveIconSize * 0.6, height: effectiveIconSize * 0.6)
                }
                .dockHoverBounce(isHovered: isHovered, position: config.position, enabled: true)

                Color.clear.frame(width: 4, height: max(4.0, Double(effectiveIconSize) * 0.10))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPopover, arrowEdge: config.position == 0 ? .top : .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("More Applications (\(hiddenApps.count))")
                    .font(.headline)
                    .foregroundColor(theme.onSurface)
                    .padding(.bottom, 4)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 4) {
                        ForEach(hiddenApps, id: \.bundleID) { app in
                            Button {
                                RunningAppsService.shared.activate(app: app)
                                isShowingPopover = false
                            } label: {
                                HStack(spacing: 8) {
                                    AppIconImage(path: app.path)
                                        .frame(width: 24, height: 24)
                                    Text(app.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(theme.onSurface)
                                    Spacer()
                                    if app.isRunning {
                                        Circle()
                                            .fill(theme.primary)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(theme.surfaceContainer)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
            .padding(12)
            .frame(width: 240)
            .background(theme.surfaceContainerLowest)
        }
    }
}
