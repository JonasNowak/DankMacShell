import SwiftUI
import DMSCore

/// Modal dialog for adding widgets to a DankBar section.
/// Matches DMS design in `settings_widget.png`.
public struct AddWidgetModal: View {
    public let section: String
    public let palette: DMSPalette
    public let onAdd: (String) -> Void
    public let onClose: () -> Void

    @State private var searchQuery: String = ""

    public init(
        section: String,
        palette: DMSPalette,
        onAdd: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.section = section
        self.palette = palette
        self.onAdd = onAdd
        self.onClose = onClose
    }

    private var filteredWidgets: [BarWidgetMeta] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            return SettingsWidgetCatalog.all
        }
        return SettingsWidgetCatalog.all.filter { meta in
            meta.name.lowercased().contains(trimmed) ||
            meta.description.lowercased().contains(trimmed) ||
            meta.id.lowercased().contains(trimmed)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color(hex: palette.primary.hex))
                    .font(.system(size: 15))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Widget to \(section.capitalized) Section")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: palette.onSurface.hex))

                    Text("Select a widget to add to the \(section) section of the bar.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: palette.outline.hex))
                }

                Spacer()

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
                TextField("Search widgets...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: palette.surfaceContainerLow.hex))
            .cornerRadius(8)

            // Widgets List
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(filteredWidgets) { meta in
                        HStack(spacing: 10) {
                            Image(systemName: meta.icon)
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: palette.primary.hex))
                                .frame(width: 26, height: 26)
                                .background(Color(hex: palette.surfaceVariant.hex).opacity(0.6))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 1) {
                                Text(meta.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: palette.onSurface.hex))
                                Text(meta.description)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: palette.outline.hex))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(action: {
                                onAdd(meta.id)
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: palette.primary.hex))
                                    .frame(width: 24, height: 24)
                                    .background(Color(hex: palette.primaryContainer.hex))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: palette.surfaceContainerLow.hex))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 320, height: 320)
        .background(Color(hex: palette.surfaceContainerHighest.hex))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: palette.primary.hex).opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
    }
}
