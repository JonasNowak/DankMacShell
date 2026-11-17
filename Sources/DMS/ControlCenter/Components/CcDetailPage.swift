import SwiftUI
import AppKit
import DMSCore
import MaterialMacLibrary

/// Container hosting a full detail subpage with breadcrumb navigation header
/// (Back, Title, Close) and slide/fade transitions matching `CcDetailPage.qml`.
/// Chrome is delegated to `MaterialComponents.MaterialDetailPage` with the bridged
/// `MaterialTheme`.
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
        MaterialDetailPage(title: title, onBack: onBack, onClose: onClose, content: content)
            .materialTheme(theme.materialTheme)
    }
}
