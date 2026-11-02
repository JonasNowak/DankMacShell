import SwiftUI
import DMSCore

/// Edit mode bottom toolbar with Add Tile, Undo, Redo, Reset, and Done actions.
public struct CcEditChrome: View {
    @ObservedObject var themeStore = ThemeStore.shared
    public let canUndo: Bool
    public let canRedo: Bool
    public let onAddTile: () -> Void
    public let onUndo: () -> Void
    public let onRedo: () -> Void
    public let onReset: () -> Void
    public let onDone: () -> Void

    public init(
        canUndo: Bool,
        canRedo: Bool,
        onAddTile: @escaping () -> Void,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.onAddTile = onAddTile
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onReset = onReset
        self.onDone = onDone
    }

    public var body: some View {
        let p = themeStore.palette

        HStack(spacing: 8) {
            // Add Tile Button
            Button(action: onAddTile) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Add Tile")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: p.primaryContainer.hex))
                .foregroundColor(Color(hex: p.onPrimaryContainer.hex))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // Undo Button
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(canUndo ? Color(hex: p.onSurface.hex) : Color(hex: p.outline.hex).opacity(0.4))
                    .frame(width: 26, height: 26)
                    .background(Color(hex: p.surfaceContainerHighest.hex).opacity(canUndo ? 1.0 : 0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canUndo)

            // Redo Button
            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(canRedo ? Color(hex: p.onSurface.hex) : Color(hex: p.outline.hex).opacity(0.4))
                    .frame(width: 26, height: 26)
                    .background(Color(hex: p.surfaceContainerHighest.hex).opacity(canRedo ? 1.0 : 0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canRedo)

            // Reset Button
            Button(action: onReset) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(hex: p.surfaceContainerHighest.hex))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Done Button
            Button(action: onDone) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Done")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color(hex: p.primary.hex))
                .foregroundColor(Color(hex: p.onPrimary.hex))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: p.surfaceContainerHigh.hex))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
