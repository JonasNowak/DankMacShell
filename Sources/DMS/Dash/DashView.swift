import SwiftUI
import DMSCore

/// Master DankDash dashboard overlay view matching the upstream DankMaterialShell design.
public struct DashView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var controller = DashController.shared

    @State private var isPresented: Bool = false
    let onClose: () -> Void

    public init(initialTab: DashTab = .overview, onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        let p = themeStore.palette
        let isBottom = ConfigStore.shared.config.barPosition.lowercased() == "bottom"

        VStack(spacing: 0) {
            // Top Tab Navigation Bar
            HStack(spacing: 0) {
                ForEach(DashTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            controller.activeTab = tab
                        }
                    }) {
                        VStack(spacing: 3) {
                            Image(systemName: tab.sfSymbol)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(controller.activeTab == tab ? Color(hex: p.onSurface.hex) : Color(hex: p.onSurfaceVariant.hex))

                            Text(tab.title)
                                .font(.system(size: 10, weight: controller.activeTab == tab ? .semibold : .medium))
                                .foregroundColor(controller.activeTab == tab ? Color(hex: p.onSurface.hex) : Color(hex: p.onSurfaceVariant.hex))

                            // Active accent underline bar
                            if controller.activeTab == tab {
                                Capsule()
                                    .fill(Color(hex: p.primary.hex))
                                    .frame(width: 28, height: 2.0)
                            } else {
                                Spacer()
                                    .frame(height: 2.0)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 7)
                        .padding(.bottom, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)

            // Subtle horizontal divider beneath tabs
            Rectangle()
                .fill(Color(hex: p.outlineVariant.hex).opacity(0.35))
                .frame(height: 1)

            // Tab Content Area
            ZStack {
                switch controller.activeTab {
                case .overview:
                    OverviewTab()
                case .media:
                    MediaPlayerTab()
                case .wallpapers:
                    WallpapersTab()
                case .weather:
                    WeatherTab()
                case .settings:
                    SettingsTab()
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: DashController.defaultWidth, height: DashController.defaultHeight)
        .background(Color(hex: p.surface.hex).opacity(0.96))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.45), lineWidth: 1)
        )

        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 10)
        .scaleEffect(isPresented ? 1.0 : 0.88, anchor: isBottom ? .bottom : .top)
        .opacity(isPresented ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                isPresented = true
            }
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }
}
