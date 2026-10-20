import SwiftUI
import DMSCore

public struct WallpaperItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: String
    public let colors: [Color]
    public let associatedTheme: String
}

/// Wallpaper gallery tab allowing live browsing and desktop wallpaper application.
public struct WallpapersTab: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @State private var selectedWallpaper: WallpaperItem?
    @State private var selectedCategory: String = "All"

    let wallpapers: [WallpaperItem] = [
        WallpaperItem(id: "purple-horizon", name: "Purple Horizon", category: "Abstract", colors: [Color(hex: "#2c1654"), Color(hex: "#7b3fa8"), Color(hex: "#d699ff")], associatedTheme: "purple"),
        WallpaperItem(id: "midnight-aurora", name: "Midnight Aurora", category: "Nature", colors: [Color(hex: "#051c24"), Color(hex: "#0c505b"), Color(hex: "#34d399")], associatedTheme: "green"),
        WallpaperItem(id: "deep-ocean", name: "Deep Ocean", category: "Minimal", colors: [Color(hex: "#0f172a"), Color(hex: "#1e3a8a"), Color(hex: "#60a5fa")], associatedTheme: "blue"),
        WallpaperItem(id: "solar-flare", name: "Solar Flare", category: "Abstract", colors: [Color(hex: "#3b0764"), Color(hex: "#9a3412"), Color(hex: "#f97316")], associatedTheme: "orange"),
        WallpaperItem(id: "crimson-dusk", name: "Crimson Dusk", category: "Nature", colors: [Color(hex: "#450a0a"), Color(hex: "#991b1b"), Color(hex: "#f87171")], associatedTheme: "red"),
        WallpaperItem(id: "golden-hour", name: "Golden Hour", category: "Minimal", colors: [Color(hex: "#422006"), Color(hex: "#a16207"), Color(hex: "#facc15")], associatedTheme: "yellow")
    ]

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let filtered = selectedCategory == "All" ? wallpapers : wallpapers.filter { $0.category == selectedCategory }
        let currentSelection = selectedWallpaper ?? wallpapers[0]

        VStack(spacing: 16) {
            // Category Filter Pills
            HStack(spacing: 10) {
                ForEach(["All", "Abstract", "Nature", "Minimal"], id: \.self) { cat in
                    Button(action: { selectedCategory = cat }) {
                        Text(cat)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(selectedCategory == cat ? Color(hex: p.primary.hex) : Color(hex: p.surfaceContainerHigh.hex))
                            .foregroundColor(selectedCategory == cat ? Color(hex: p.onPrimary.hex) : Color(hex: p.onSurface.hex))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()

                Button(action: {
                    themeStore.apply(theme: currentSelection.associatedTheme)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Apply to DMS")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: p.primary.hex))
                    .foregroundColor(Color(hex: p.onPrimary.hex))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Wallpaper Grid
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(filtered) { wp in
                        Button(action: { selectedWallpaper = wp }) {
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: wp.colors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(height: 95)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(wp.id == currentSelection.id ? Color(hex: p.primary.hex) : Color.clear, lineWidth: 2.5)
                                    )

                                HStack {
                                    Text(wp.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: p.onSurface.hex))
                                    Spacer()
                                    Text(wp.category)
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: p.outline.hex))
                                }
                                .padding(.horizontal, 4)
                            }
                            .padding(8)
                            .background(Color(hex: p.surfaceContainerHigh.hex))
                            .cornerRadius(18)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
