import Foundation
import AppKit
import DMSCore

/// Background monitor for macOS pasteboard changes.
@MainActor
public final class ClipboardService: ObservableObject {
    public static let shared = ClipboardService()

    @Published public private(set) var items: [ClipboardItem] = []
    private var lastChangeCount: Int
    private var timer: Timer?

    private init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        self.items = ClipboardStore.shared.getItems()

        // Fast poll on runloop
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPasteboard()
            }
        }
    }

    public func checkPasteboard() {
        let count = NSPasteboard.general.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else { return }

        if ClipboardStore.shared.add(text: str) != nil {
            self.items = ClipboardStore.shared.getItems()
        }
    }

    public func copyItem(text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        self.lastChangeCount = pb.changeCount
        ClipboardStore.shared.add(text: text)
        self.items = ClipboardStore.shared.getItems()
        ToastCenter.shared.show(icon: "doc.on.doc.fill", message: "Copied to Clipboard")
    }

    public func removeItem(id: UUID) {
        ClipboardStore.shared.remove(id: id)
        self.items = ClipboardStore.shared.getItems()
    }

    public func clearAll() {
        ClipboardStore.shared.clear()
        self.items = []
        ToastCenter.shared.show(icon: "trash.fill", message: "Clipboard History Cleared")
    }

    public func search(query: String) -> [ClipboardItem] {
        ClipboardStore.shared.search(query: query)
    }
}
