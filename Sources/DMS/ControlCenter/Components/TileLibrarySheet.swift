import SwiftUI
import DMSCore

/// Searchable Tile Library sheet for browsing and re-adding removed Control Center tiles.
public struct TileLibrarySheet: View {
    @ObservedObject var themeStore = ThemeStore.shared
    public let activeWidgetIDs: Set<String>
    public let onAddWidget: (ControlCenterWidgetConfig) -> Void
    public let onClose: () -> Void

    @State private var searchQuery: String = ""
    @State private var selectedCategory: String = "All"

    public init(
        activeWidgetIDs: Set<String>,
        onAddWidget: @escaping (ControlCenterWidgetConfig) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.activeWidgetIDs = activeWidgetIDs
        self.onAddWidget = onAddWidget
        self.onClose = onClose
    }

    private var availableCatalog: [ControlCenterWidgetConfig] {
        let all = ControlCenterUtils.catalogWidgets.filter { !activeWidgetIDs.contains($0.id) }
        let filteredByCategory = (selectedCategory == "All") ? all : all.filter { ControlCenterUtils.category(for: $0.id) == selectedCategory }
        let clean = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return filteredByCategory }
        return filteredByCategory.filter {
            ControlCenterUtils.title(for: $0.id).lowercased().contains(clean)
                || ControlCenterUtils.subtitle(for: $0.id).lowercased().contains(clean)
        }
    }

    private var categories: [String] {
        var set = Set(ControlCenterUtils.catalogWidgets.map { ControlCenterUtils.category(for: $0.id) })
        set.insert("All")
        return ["All"] + set.filter { $0 != "All" }.sorted()
    }

    public var body: some View {
        let p = themeStore.palette

        VStack(spacing: 10) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "plus.square.fill.on.square.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: p.primary.hex))

                    Text("Tile Library")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: p.onSurface.hex))
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                }
                .buttonStyle(.plain)
            }

            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: p.outline.hex))
                TextField("Search available tiles…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(hex: p.surfaceContainerLow.hex))
            .cornerRadius(8)

            // Category Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(categories, id: \.self) { cat in
                        Button(action: { selectedCategory = cat }) {
                            Text(cat)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(selectedCategory == cat ? Color(hex: p.primary.hex) : Color(hex: p.surfaceContainerHigh.hex))
                                .foregroundColor(selectedCategory == cat ? Color(hex: p.onPrimary.hex) : Color(hex: p.onSurface.hex))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Available Tiles List
            if availableCatalog.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: p.primary.hex))
                    Text("All catalog tiles are currently in your Control Center!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(availableCatalog) { tile in
                            HStack(spacing: 8) {
                                Image(systemName: ControlCenterUtils.icon(for: tile.id))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: p.primary.hex))
                                    .frame(width: 24, height: 24)
                                    .background(Color(hex: p.primaryContainer.hex).opacity(0.4))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ControlCenterUtils.title(for: tile.id))
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color(hex: p.onSurface.hex))
                                    Text(ControlCenterUtils.subtitle(for: tile.id))
                                        .font(.system(size: 9))
                                        .foregroundColor(Color(hex: p.outline.hex))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Button(action: {
                                    onAddWidget(tile)
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "plus")
                                        Text("Add")
                                    }
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: p.primary.hex))
                                    .foregroundColor(Color(hex: p.onPrimary.hex))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: p.surfaceContainerHigh.hex))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .frame(width: 340, height: 280)
        .background(Color(hex: p.surfaceContainer.hex))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: p.outlineVariant.hex).opacity(0.35), lineWidth: 1)
        )
    }
}
