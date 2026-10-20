import SwiftUI
import DMSCore

/// Navigation sidebar for DMS Settings.
/// Matches DMS design from `settings.png`, `settings_widget.png`, and `settings_plugin.png`.
public struct SettingsSidebar: View {
    @Binding public var selectedTab: DMSSettingsTab
    @Binding public var searchQuery: String
    public let palette: DMSPalette

    @State private var expandedCategories: Set<SettingsCategory> = [
        .personalization,
        .primaryBar
    ]

    public init(
        selectedTab: Binding<DMSSettingsTab>,
        searchQuery: Binding<String>,
        palette: DMSPalette
    ) {
        self._selectedTab = selectedTab
        self._searchQuery = searchQuery
        self.palette = palette
    }

    private var username: String {
        let full = NSFullUserName()
        return full.isEmpty ? NSUserName() : full
    }

    private var hostSubtitle: String {
        let host = ProcessInfo.processInfo.hostName
        if host.hasSuffix(".local") {
            return String(host.dropLast(6))
        }
        return "macOS"
    }

    private var searchResults: [DMSSettingsTab] {
        SettingsSearchIndex.filter(query: searchQuery)
    }

    public var body: some View {
        VStack(spacing: 10) {
            // User Profile Header (matching settings.png & settings_widget.png)
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .foregroundColor(Color(hex: palette.primary.hex))

                VStack(alignment: .leading, spacing: 2) {
                    Text(username)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: palette.onSurface.hex))
                        .lineLimit(1)

                    Text(hostSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: palette.outline.hex))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: palette.outline.hex))
                    .font(.system(size: 12))

                TextField("Search settings...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: palette.outline.hex))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(hex: palette.surfaceContainerHigh.hex))
            .cornerRadius(10)
            .padding(.horizontal, 8)

            // Navigation List
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // Flat Search Results
                            ForEach(searchResults) { tab in
                                tabButton(tab: tab)
                                    .id(tab.id)
                            }
                        } else {
                            // Grouped Categories
                            ForEach(SettingsCategory.allCases) { cat in
                                let catTabs = DMSSettingsTab.tabs(for: cat)
                                if catTabs.count == 1, let singleTab = catTabs.first {
                                    // Single tab categories (Shortcuts, Power, Plugins, About)
                                    tabButton(tab: singleTab)
                                        .id(singleTab.id)
                                } else {
                                    // Multi-tab expandable categories
                                    let isExpanded = expandedCategories.contains(cat)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Button(action: {
                                            if isExpanded {
                                                expandedCategories.remove(cat)
                                            } else {
                                                expandedCategories.insert(cat)
                                            }
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: cat.icon)
                                                    .font(.system(size: 12))
                                                .foregroundColor(Color(hex: palette.outline.hex))
                                                .frame(width: 16)

                                                Text(cat.rawValue)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(Color(hex: palette.outline.hex))

                                                Spacer()

                                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(Color(hex: palette.outline.hex))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                        }
                                        .buttonStyle(.plain)

                                        if isExpanded {
                                            VStack(spacing: 2) {
                                                ForEach(catTabs) { tab in
                                                    tabButton(tab: tab, indented: true)
                                                        .id(tab.id)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.bottom, 4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .onChange(of: selectedTab) { _, newTab in
                    expandedCategories.insert(newTab.category)
                    withAnimation {
                        proxy.scrollTo(newTab.id, anchor: .center)
                    }
                }
                .onAppear {
                    expandedCategories.insert(selectedTab.category)
                    proxy.scrollTo(selectedTab.id, anchor: .center)
                }
            }
        }
        .padding(.vertical, 10)
        .frame(width: 230)
        .background(Color(hex: palette.surfaceContainerLow.hex))
    }

    @ViewBuilder
    private func tabButton(tab: DMSSettingsTab, indented: Bool = false) -> some View {
        let isSelected = selectedTab == tab
        let iconColor = isSelected ? Color(hex: palette.primary.hex) : Color(hex: palette.onSurfaceVariant.hex)
        let textColor = isSelected ? Color(hex: palette.primary.hex) : Color(hex: palette.onSurface.hex)
        let textWeight: Font.Weight = isSelected ? .bold : .medium
        let bgColor = isSelected ? Color(hex: palette.primaryContainer.hex) : Color.clear

        Button(action: {
            selectedTab = tab
        }) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                    .frame(width: 18)

                Text(tab.rawValue)
                    .font(.system(size: 12, weight: textWeight))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.leading, indented ? 16 : 10)
            .padding(.trailing, 8)
            .padding(.vertical, 7)
            .background(bgColor)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
