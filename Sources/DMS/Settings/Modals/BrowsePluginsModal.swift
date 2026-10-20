import SwiftUI
import DMSCore

/// Modal dialog for browsing and installing plugins from the registry.
/// Matches DMS design in `settings_plugin.png`.
public struct BrowsePluginsModal: View {
    public let palette: DMSPalette
    @ObservedObject var pluginService = PluginService.shared
    public let onClose: () -> Void

    @State private var searchQuery: String = ""
    @State private var hideThirdParty: Bool = false

    public init(
        palette: DMSPalette,
        onClose: @escaping () -> Void
    ) {
        self.palette = palette
        self.onClose = onClose
    }

    private var filteredPlugins: [DMSPlugin] {
        PluginFilter.filter(
            plugins: pluginService.plugins,
            query: searchQuery,
            hideThirdParty: hideThirdParty
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(Color(hex: palette.primary.hex))
                    .font(.system(size: 15))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Browse Plugins")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: palette.onSurface.hex))

                    Text("Install plugins from the DMS plugin registry")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: palette.outline.hex))
                }

                Spacer()

                // Hide 3rd Party Toggle Button
                Button(action: {
                    hideThirdParty.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: hideThirdParty ? "eye.slash.fill" : "eye.slash")
                        Text("Hide 3rd Party")
                    }
                    .font(.system(size: 10, weight: hideThirdParty ? .bold : .medium))
                    .foregroundColor(hideThirdParty ? Color(hex: palette.onPrimaryContainer.hex) : Color(hex: palette.onSurfaceVariant.hex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(hideThirdParty ? Color(hex: palette.primaryContainer.hex) : Color(hex: palette.surfaceContainerLow.hex))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // Refresh Button
                Button(action: {
                    // Trigger refresh / reload registry
                    ToastCenter.shared.show(icon: "arrow.clockwise", message: "Registry refreshed")
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                        .frame(width: 22, height: 22)
                        .background(Color(hex: palette.surfaceContainerLow.hex))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Close Button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                        .frame(width: 22, height: 22)
                        .background(Color(hex: palette.surfaceContainerLow.hex))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: palette.outline.hex))
                    .font(.system(size: 11))
                TextField("Search plugins, tags, or authors...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: palette.surfaceContainerLow.hex))
            .cornerRadius(8)

            // Plugins List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(filteredPlugins) { plugin in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: plugin.icon)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: palette.primary.hex))
                                .frame(width: 28, height: 28)
                                .background(Color(hex: palette.surfaceVariant.hex).opacity(0.6))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(plugin.name)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color(hex: palette.onSurface.hex))

                                    // Official / 3rd Party Badge
                                    if plugin.isOfficial {
                                        Text("official")
                                            .font(.system(size: 8, weight: .semibold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color(hex: palette.secondaryContainer.hex))
                                            .foregroundColor(Color(hex: palette.onSecondaryContainer.hex))
                                            .cornerRadius(4)
                                    } else {
                                        Text("3rd party")
                                            .font(.system(size: 8, weight: .semibold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                    }
                                }

                                Text("by \(plugin.author)")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: palette.outline.hex))

                                Text(plugin.description)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: palette.onSurfaceVariant.hex))
                                    .lineLimit(2)

                                // Tags pills
                                if !plugin.tags.isEmpty {
                                    HStack(spacing: 4) {
                                        ForEach(plugin.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color(hex: palette.surfaceContainerLow.hex))
                                                .foregroundColor(Color(hex: palette.outline.hex))
                                                .cornerRadius(3)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                            }

                            Spacer()

                            // Action Button: Install or Installed
                            if plugin.isInstalled {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark")
                                    Text("Installed")
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: palette.outline.hex))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color(hex: palette.surfaceContainerLow.hex))
                                .cornerRadius(6)
                            } else {
                                Button(action: {
                                    pluginService.installPlugin(id: plugin.id)
                                    ToastCenter.shared.show(icon: "checkmark.circle.fill", message: "Installed \(plugin.name)")
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "arrow.down")
                                        Text("Install")
                                    }
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: palette.onPrimary.hex))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: palette.primary.hex))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .background(Color(hex: palette.surfaceContainerLow.hex))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 380, height: 340)
        .background(Color(hex: palette.surfaceContainerHighest.hex))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: palette.primary.hex).opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
    }
}
