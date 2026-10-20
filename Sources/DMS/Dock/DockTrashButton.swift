import SwiftUI
import AppKit
import DMSCore

/// Integrated Trash button in the Desktop Dock with empty vs full icon morphing,
/// item count badge, proximity scaling, and context menu.
public struct DockTrashButton: View {
    public let config: DockConfig
    public let scale: Double
    public let isHovered: Bool

    @ObservedObject private var theme = ThemeStore.shared
    @State private var trashCount: Int = 0

    public init(
        config: DockConfig,
        scale: Double = 1.0,
        isHovered: Bool = false
    ) {
        self.config = config
        self.scale = scale
        self.isHovered = isHovered
    }

    private var effectiveIconSize: CGFloat {
        CGFloat(config.iconSize) * CGFloat(scale)
    }

    private var trashURL: URL {
        FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSString(string: "~/.Trash").expandingTildeInPath)
    }

    public var body: some View {
        Button {
            openTrash()
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: trashCount > 0 ? "trash.fill" : "trash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(trashCount > 0 ? theme.primary : theme.onSurfaceVariant)
                        .frame(width: effectiveIconSize * 0.75, height: effectiveIconSize * 0.75)
                        .padding(effectiveIconSize * 0.125)
                        .dockHoverBounce(isHovered: isHovered, position: config.position, enabled: true)

                    if trashCount > 0 {
                        Text("\(trashCount)")
                            .font(.system(size: max(8, effectiveIconSize * 0.22), weight: .bold, design: .rounded))
                            .foregroundColor(theme.onError)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(theme.error)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -2)
                    }
                }
                .frame(width: effectiveIconSize, height: effectiveIconSize)

                // Bottom spacer matching app indicator lane height
                Color.clear.frame(width: 4, height: max(4.0, Double(effectiveIconSize) * 0.10))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Text("Trash (\(trashCount) items)")
                .font(.headline)
            Divider()
            Button("Open Trash") {
                openTrash()
            }
            if trashCount > 0 {
                Divider()
                Button("Empty Trash (\(trashCount))") {
                    emptyTrash()
                }
            }
        }
        .onAppear {
            refreshCount()
        }
    }

    public func refreshCount() {
        if let contents = try? FileManager.default.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil) {
            trashCount = contents.count
        } else {
            trashCount = 0
        }
    }

    private func openTrash() {
        NSWorkspace.shared.open(trashURL)
    }

    private func emptyTrash() {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to empty the Trash?"
        alert.informativeText = "Items in the Trash will be permanently erased."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Empty Trash")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let items = try? FileManager.default.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil) {
                for item in items {
                    try? FileManager.default.removeItem(at: item)
                }
            }
            let script = NSAppleScript(source: "tell application \"Finder\" to empty trash")
            script?.executeAndReturnError(nil)
            refreshCount()
        }
    }
}
