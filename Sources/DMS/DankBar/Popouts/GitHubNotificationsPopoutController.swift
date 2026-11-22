import AppKit
import SwiftUI
import DMSCore

/// Zero-size `NSViewRepresentable` placed behind the GitHub bar pill. It reports the
/// hosting pill view to `GitHubNotificationsPopoutController.shared` so the popout can
/// anchor to the exact pill frame instead of the raw mouse location.
public struct GitHubPillAnchorReader: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> AnchorView {
        AnchorView()
    }

    public func updateNSView(_ nsView: AnchorView, context: Context) {}

    public final class AnchorView: NSView {
        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                GitHubNotificationsPopoutController.shared.anchorView = self
            }
        }
    }
}

/// Dedicated DankBar popout for GitHub notifications: sign-in (Keychain token or gh CLI)
/// plus a rich unread-notification list with mark-as-read actions.
@MainActor
public final class GitHubNotificationsPopoutController: ObservableObject, PopoutController {
    public static let shared = GitHubNotificationsPopoutController()

    private var panel: ShellPanel?
    @Published public private(set) var isVisible: Bool = false
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    /// Last known GitHub bar pill view, used as the popout anchor when available.
    var anchorView: NSView?

    public var popoutID: String { "github-notifications" }
    public var popoutPanel: ShellPanel? { panel }
    public var isPopoutVisible: Bool { isVisible }
    public func hidePopout() { close() }

    private init() {}

    // MARK: - Anchor-aware API

    public func toggle(from anchor: NSView? = nil) {
        if isVisible {
            close()
        } else {
            open(from: anchor)
        }
    }

    public func open(from anchor: NSView? = nil) {
        show(anchorX: Self.anchorX(for: anchor))
    }

    public func close() {
        hide()
    }

    /// Resolves the screen X coordinate for the popout: pill frame center when an anchor
    /// view is known, otherwise the current mouse location.
    private static func anchorX(for anchor: NSView?) -> CGFloat {
        let view = anchor ?? shared.anchorView
        if let view, let window = view.window {
            let rectInWindow = view.convert(view.bounds, to: nil)
            let screenRect = window.convertToScreen(rectInWindow)
            return screenRect.midX
        }
        return NSEvent.mouseLocation.x
    }

    // MARK: - Panel lifecycle (ShellPanel pattern shared by all DankBar popouts)

    public func toggle(anchorX: CGFloat? = nil) {
        if isVisible {
            hide()
        } else {
            show(anchorX: anchorX)
        }
    }

    public func show(anchorX: CGFloat? = nil) {
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first else { return }

        // Close peer popouts and non-popout DMS panels
        PopoutCoordinator.shared.dismissAll(except: popoutID)
        DashController.shared.hide()
        ProcessListController.shared.hide()
        ControlCenterController.shared.hide()

        // Close any existing panel BEFORE creating a new one (fixes leaked ghost panels on double-show)
        if let existing = panel {
            existing.orderOut(nil)
            panel = nil
        }

        let bodyWidth: CGFloat = 360
        let bodyHeight: CGFloat = 420

        let rect = PopoutLayoutHelper.frame(
            bodyWidth: bodyWidth,
            bodyHeight: bodyHeight,
            anchorX: anchorX,
            screen: screen
        )

        let panel = ShellPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.onEscape = { [weak self] in
            self?.hide()
        }

        let rootView = GitHubNotificationsPopoutView(ownerPanel: panel) { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: rootView)

        self.panel = panel
        self.isVisible = true

        PopoutCoordinator.shared.register(self)
        PopoutAnimationHelper.animateIn(panel: panel, targetFrame: rect, screen: screen)
        installClickMonitors()
    }

    public func hide() {
        guard isVisible else { return }
        removeClickMonitors()
        PopoutCoordinator.shared.unregister(popoutID)
        isVisible = false

        let panelToClose = self.panel
        let screen = panelToClose?.screen ?? NSScreen.main
        self.panel = nil

        PopoutAnimationHelper.animateOut(panel: panelToClose, screen: screen)
    }

    private func installClickMonitors() {
        removeClickMonitors()
        let handler: (NSEvent) -> NSEvent? = { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self = self, self.isVisible else { return }
                let clickLoc = NSEvent.mouseLocation
                if let p = self.panel, NSMouseInRect(clickLoc, p.frame, false) { return }
                if PopoutCoordinator.shared.isPointInsideAnyBar(clickLoc) { return }
                self.hide()
            }
            return event
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: handler)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { event in _ = handler(event) })
    }

    private func removeClickMonitors() {
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}

/// M3 popout view for GitHub sign-in and the unread notifications list (360x420).
public struct GitHubNotificationsPopoutView: View {
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var gh = GitHubNotificationsService.shared
    @State private var tokenInput: String = ""
    let ownerPanel: NSPanel?
    let onClose: () -> Void

    public init(ownerPanel: NSPanel? = nil, onClose: @escaping () -> Void) {
        self.ownerPanel = ownerPanel
        self.onClose = onClose
    }

    public var body: some View {
        PopoutSurfaceContainer(bodyWidth: 360, bodyHeight: 420, ownerPanel: ownerPanel) {
            VStack(spacing: 0) {
                header
                Divider().background(theme.outlineVariant.opacity(0.4))
                if gh.isSignedIn {
                    notificationsList
                } else {
                    signInCard
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.badge.fill")
                .font(ThemeStore.shared.font(size: 13, weight: .bold))
                .foregroundColor(theme.primary)
            Text("GitHub Notifications")
                .font(ThemeStore.shared.font(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(theme.onSurface)
            if gh.isSignedIn, let username = gh.username {
                Text("@\(username)")
                    .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                    .foregroundColor(theme.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.primaryContainer)
                    .clipShape(Capsule())
            }
            Spacer()
            headerButton(icon: "arrow.clockwise", tooltip: "Refresh") {
                gh.refresh()
            }
            if gh.isSignedIn && gh.unreadCount > 0 {
                headerButton(icon: "checkmark.circle", tooltip: "Mark All Read") {
                    gh.markAllAsRead()
                }
            }
            headerButton(icon: "safari", tooltip: "Open on Web") {
                gh.openNotifications()
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                    .foregroundColor(theme.onSurfaceVariant)
                    .frame(width: 22, height: 22)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.panelHeaderBackground)
    }

    private func headerButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                .foregroundColor(theme.onSurfaceVariant)
                .frame(width: 22, height: 22)
                .background(theme.surfaceContainerHigh)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Sign-in card (not signed in)

    private var signInCard: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Sign in to GitHub")
                    .font(ThemeStore.shared.font(size: 12, weight: .bold))
                    .foregroundColor(theme.onSurface)
                Text("Track unread notifications right from DankBar. The token is stored in your macOS Keychain only.")
                    .font(ThemeStore.shared.font(size: 10, weight: .medium))
                    .foregroundColor(theme.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: { gh.openCreateTokenPage() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .font(ThemeStore.shared.font(size: 11, weight: .bold))
                        Text("Create Scoped Token on GitHub")
                            .font(ThemeStore.shared.font(size: 11, weight: .bold))
                    }
                    .foregroundColor(theme.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(theme.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                SecureField("Paste GitHub token (ghp_... / github_pat_...)", text: $tokenInput)
                    .font(ThemeStore.shared.font(size: 11, weight: .medium, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(theme.surfaceContainerHigh)
                    .cornerRadius(8)

                Button(action: {
                    Task { await gh.signInWithToken(tokenInput) }
                }) {
                    HStack(spacing: 6) {
                        if gh.isAuthenticating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "lock.open.fill")
                                .font(ThemeStore.shared.font(size: 11, weight: .bold))
                        }
                        Text(gh.isAuthenticating ? "Signing In..." : "Sign In")
                            .font(ThemeStore.shared.font(size: 11, weight: .bold))
                    }
                    .foregroundColor(theme.onPrimaryContainer)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(theme.primaryContainer)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(gh.isAuthenticating || tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                HStack(spacing: 8) {
                    Button(action: {
                        Task { await gh.detectGHCLIAuth() }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "terminal.fill")
                                .font(ThemeStore.shared.font(size: 10, weight: .bold))
                            Text("Use gh CLI")
                                .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                        }
                        .foregroundColor(theme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(theme.surfaceContainerHigh)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: { gh.launchGHCLIWebLogin() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(ThemeStore.shared.font(size: 10, weight: .bold))
                            Text("gh Web Login")
                                .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                        }
                        .foregroundColor(theme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(theme.surfaceContainerHigh)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                if let authError = gh.authError {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(ThemeStore.shared.font(size: 10, weight: .bold))
                            .foregroundColor(theme.error)
                        Text(authError)
                            .font(ThemeStore.shared.font(size: 10, weight: .medium))
                            .foregroundColor(theme.error)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .background(theme.error.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(12)
        }
    }

    // MARK: - Notifications list (signed in)

    private var notificationsList: some View {
        VStack(spacing: 0) {
            if gh.notifications.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(ThemeStore.shared.font(size: 28, weight: .bold))
                        .foregroundColor(theme.primary)
                    Text("All caught up!")
                        .font(ThemeStore.shared.font(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(theme.onSurface)
                    Text("No unread GitHub notifications.")
                        .font(ThemeStore.shared.font(size: 10, weight: .medium))
                        .foregroundColor(theme.onSurfaceVariant)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 6) {
                        ForEach(gh.notifications) { item in
                            notificationRow(item)
                        }
                    }
                    .padding(10)
                }
            }

            Divider().background(theme.outlineVariant.opacity(0.4))

            HStack(spacing: 8) {
                Text(authMethodBadgeText)
                    .font(ThemeStore.shared.font(size: 9, weight: .bold))
                    .foregroundColor(theme.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.surfaceContainerHigh)
                    .clipShape(Capsule())
                if let lastUpdated = gh.lastUpdated {
                    Text("Updated \(lastUpdated, style: .relative) ago")
                        .font(ThemeStore.shared.font(size: 9, weight: .medium))
                        .foregroundColor(theme.onSurfaceVariant)
                }
                Spacer()
                Button(action: { gh.signOut() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(ThemeStore.shared.font(size: 10, weight: .bold))
                        Text("Sign Out")
                            .font(ThemeStore.shared.font(size: 10, weight: .semibold))
                    }
                    .foregroundColor(theme.error)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(theme.error.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
    }

    private var authMethodBadgeText: String {
        switch gh.authMethod {
        case .keychainToken: return "KEYCHAIN TOKEN"
        case .ghCLI: return "GH CLI"
        case .none: return "NOT SIGNED IN"
        }
    }

    private func notificationRow(_ item: GitHubNotificationItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: { gh.openNotification(item) }) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: GitHubNotificationParser.sfSymbol(forSubjectType: item.subjectType))
                            .font(ThemeStore.shared.font(size: 12, weight: .bold))
                            .foregroundColor(item.unread ? theme.primary : theme.onSurfaceVariant)
                            .frame(width: 18)
                        Text(item.repositoryFullName)
                            .font(ThemeStore.shared.font(size: 9, weight: .bold))
                            .foregroundColor(theme.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(theme.surfaceContainerHigh)
                            .clipShape(Capsule())
                        if item.unread {
                            Circle()
                                .fill(theme.primary)
                                .frame(width: 6, height: 6)
                        }
                        Spacer()
                        Text(item.reason.capitalized)
                            .font(ThemeStore.shared.font(size: 8, weight: .bold))
                            .foregroundColor(theme.onSurfaceVariant)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(theme.surfaceContainerHigh)
                            .clipShape(Capsule())
                    }
                    Text(item.title)
                        .font(ThemeStore.shared.font(size: 11, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: { gh.markAsRead(threadID: item.id) }) {
                Image(systemName: "checkmark.circle")
                    .font(ThemeStore.shared.font(size: 13, weight: .semibold))
                    .foregroundColor(theme.onSurfaceVariant)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Mark as read")
        }
        .padding(8)
        .background(theme.surfaceContainerLow)
        .cornerRadius(10)
    }
}
