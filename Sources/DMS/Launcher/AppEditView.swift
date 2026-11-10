import SwiftUI
import AppKit
import DMSCore

/// In-launcher application editor sheet (spec 18-launcher.md `AppEditView.qml`).
/// Edits the per-app `AppOverrideEntry` (display name, launch arguments, hidden flag, tags)
/// persisted via `ConfigStore` under `apps.perApp[bundleID]`.
public struct AppEditView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var configStore = ConfigStore.shared
    @Environment(\.dismiss) private var dismiss

    public let app: AppItem

    @State private var displayName: String
    @State private var launchArgs: String
    @State private var hidden: Bool
    @State private var tags: String

    public init(app: AppItem) {
        self.app = app
        let existing = ConfigStore.shared.config.apps.perApp[app.bundleID]
        self._displayName = State(initialValue: existing?.displayName ?? "")
        self._launchArgs = State(initialValue: (existing?.launchArguments ?? []).joined(separator: " "))
        self._hidden = State(initialValue: existing?.hiddenFromLauncher ?? false)
        self._tags = State(initialValue: (existing?.tags ?? []).joined(separator: ", "))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                AppIconImage(path: app.path, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit Application")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(theme.onSurface)
                    Text(app.bundleID)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.onSurfaceVariant)
                        .frame(width: 28, height: 28)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(theme.panelHeaderBackground)

            Divider()
                .background(theme.outlineVariant.opacity(0.5))

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppEditField(
                        title: "Display Name",
                        placeholder: app.name,
                        text: $displayName,
                        theme: theme
                    )

                    AppEditField(
                        title: "Launch Arguments",
                        placeholder: "e.g. --incognito --new-window",
                        text: $launchArgs,
                        theme: theme
                    )

                    AppEditField(
                        title: "Tags",
                        placeholder: "comma-separated, e.g. web, browser",
                        text: $tags,
                        theme: theme
                    )

                    Toggle(isOn: $hidden) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hidden from launcher")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.onSurface)
                            Text("The app never appears in launcher results")
                                .font(.system(size: 11))
                                .foregroundColor(theme.onSurfaceVariant)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(theme.primary)
                }
                .padding(18)
            }

            Divider()
                .background(theme.outlineVariant.opacity(0.5))

            // Footer actions
            HStack(spacing: 10) {
                Button {
                    resetToDefaults()
                } label: {
                    Text("Reset")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.error)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(theme.errorContainer.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.onSurfaceVariant)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    save()
                } label: {
                    Text("Save")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(theme.onPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(theme.panelHeaderBackground)
        }
        .frame(width: 440, height: 460)
        .background(GlassSurfaceBackground())
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.panelBorderColor, lineWidth: 1)
        )
    }

    private func save() {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let args = AppOverrideApplier.splitShellArguments(launchArgs)
        let tagList = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let entry = AppOverrideEntry(
            displayName: name.isEmpty ? nil : name,
            launchArguments: args.isEmpty ? nil : args,
            hiddenFromLauncher: hidden,
            tags: tagList
        )

        configStore.update { cfg in
            if entry.isDefault {
                cfg.apps.perApp.removeValue(forKey: app.bundleID)
            } else {
                cfg.apps.perApp[app.bundleID] = entry
            }
        }
        ToastCenter.shared.show(icon: "checkmark.circle.fill", message: "Saved overrides for \(app.name)")
        dismiss()
    }

    private func resetToDefaults() {
        configStore.update { cfg in
            cfg.apps.perApp.removeValue(forKey: app.bundleID)
        }
        displayName = ""
        launchArgs = ""
        hidden = false
        tags = ""
        ToastCenter.shared.show(icon: "arrow.counterclockwise", message: "Overrides reset for \(app.name)")
    }
}

/// Labeled text field row used by `AppEditView`.
private struct AppEditField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let theme: ThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(theme.outline)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(theme.onSurface)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(theme.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
