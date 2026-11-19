import Foundation
import AppKit
import Combine
import DMSCore

/// Background monitor for macOS pasteboard changes.
@MainActor
public final class ClipboardService: ObservableObject {
    public static let shared = ClipboardService()

    @Published public private(set) var items: [ClipboardItem] = []
    private var lastChangeCount: Int
    private var timer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var maxItemsCancellable: AnyCancellable?

    private init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        self.items = ClipboardStore.shared.getItems()
        ClipboardStore.shared.maxItemsValue = ConfigStore.shared.config.clipboardMaxItems

        // Keep the store's cap in sync with the live config.
        maxItemsCancellable = ConfigStore.shared.$config
            .map(\.clipboardMaxItems)
            .removeDuplicates()
            .sink { [weak self] maxItems in
                Task { @MainActor [weak self] in
                    ClipboardStore.shared.maxItemsValue = maxItems
                    self?.items = ClipboardStore.shared.getItems()
                }
            }

        // Fast poll on runloop
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPasteboard()
            }
        }

        // App-deactivation hook: when an app loses focus it may have just written the
        // pasteboard (e.g. a password manager copying a secret). Checking immediately with
        // the *deactivating* app's bundle ID closes the polling-window TOCTOU bypass.
        workspaceObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    return
                }
                self?.checkPasteboard(
                    sourceBundleID: app.bundleIdentifier,
                    sourceAppName: app.localizedName
                )
            }
        }
    }

    deinit {
        if let workspaceObserver {
            NotificationCenter.default.removeObserver(workspaceObserver)
        }
        maxItemsCancellable?.cancel()
    }

    public func checkPasteboard() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        checkPasteboard(
            sourceBundleID: frontmost?.bundleIdentifier,
            sourceAppName: frontmost?.localizedName
        )
    }

    /// Checks the pasteboard for a new change, attributing it to the given source app.
    public func checkPasteboard(sourceBundleID: String?, sourceAppName: String?) {
        let count = NSPasteboard.general.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        let pb = NSPasteboard.general

        // v0.6 CLIP: sensitive-content filter. Union of the types of ALL pasteboard items —
        // one concealed/transient/auto-generated representation poisons the whole change.
        let allTypes = pb.pasteboardItems?.flatMap { $0.types.map(\.rawValue) } ?? []
        let filterEnabled = ConfigStore.shared.config.clipboardFilterSensitive
        guard ClipboardFilter.shouldRecord(
            pasteboardTypes: allTypes,
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            filterEnabled: filterEnabled
        ) else { return }

        guard let str = pb.string(forType: .string), !str.isEmpty else { return }

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
