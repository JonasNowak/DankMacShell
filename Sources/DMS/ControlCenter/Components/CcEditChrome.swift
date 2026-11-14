import SwiftUI
import DMSCore
import MaterialMacLibrary

/// Edit mode bottom toolbar with Add Tile, Undo, Redo, Reset, and Done actions.
/// The Add Tile / Reset / Done bar chrome is delegated to
/// `MaterialComponents.MaterialFloatingEditChrome` (`.bar` style) with the bridged
/// `MaterialTheme`; Undo/Redo remain DMS-specific circular actions wired to the
/// control-center undo stack.
public struct CcEditChrome: View {
    @ObservedObject var themeStore = ThemeStore.shared
    public let canUndo: Bool
    public let canRedo: Bool
    public let onAddTile: () -> Void
    public let onUndo: () -> Void
    public let onRedo: () -> Void
    public let onReset: () -> Void
    public let onDone: () -> Void

    @Environment(\.materialTheme) private var m3

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
        HStack(spacing: 8) {
            undoButton
            redoButton
            MaterialFloatingEditChrome(
                addTitle: "Add Tile",
                onAdd: onAddTile,
                onReset: onReset,
                onDone: onDone,
                style: .bar
            )
        }
        .materialTheme(themeStore.materialTheme)
    }

    private var undoButton: some View {
        Button(action: onUndo) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(canUndo ? m3.onSurface : m3.outline.opacity(0.4))
                .frame(width: 26, height: 26)
                .background(m3.surfaceContainerHighest.opacity(canUndo ? 1.0 : 0.5))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canUndo)
    }

    private var redoButton: some View {
        Button(action: onRedo) {
            Image(systemName: "arrow.uturn.forward")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(canRedo ? m3.onSurface : m3.outline.opacity(0.4))
                .frame(width: 26, height: 26)
                .background(m3.surfaceContainerHighest.opacity(canRedo ? 1.0 : 0.5))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canRedo)
    }
}
