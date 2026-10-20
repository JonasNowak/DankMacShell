import SwiftUI
import AppKit
import DMSCore

/// Container hosting a full detail subpage with breadcrumb navigation header
/// (Back, Title, Close) and slide/fade transitions matching `CcDetailPage.qml`.
public struct CcDetailPage<Content: View>: View {
    public let title: String
    public let onBack: () -> Void
    public let onClose: () -> Void
    @ViewBuilder public let content: () -> Content

    @ObservedObject private var theme = ThemeStore.shared

    public init(
        title: String,
        onBack: @escaping () -> Void,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onBack = onBack
        self.onClose = onClose
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Breadcrumb Header
            HStack(spacing: 12) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.onSurface)
                        .frame(width: 30, height: 30)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onSurface)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.onSurfaceVariant)
                        .frame(width: 26, height: 26)
                        .background(theme.surfaceContainerHigh)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.surfaceContainerHigh.opacity(0.5))

            Divider()
                .background(theme.outlineVariant.opacity(0.3))

            // MARK: - Subpage Content
            ScrollView(.vertical, showsIndicators: true) {
                content()
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surfaceContainer)
    }
}
