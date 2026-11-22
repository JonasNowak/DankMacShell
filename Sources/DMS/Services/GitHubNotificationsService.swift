import Foundation
import Combine
import AppKit
import Security
import DMSCore

/// macOS Keychain storage for the GitHub access token.
/// Tokens are NEVER persisted to UserDefaults or settings.json — only the Keychain.
private enum GitHubKeychainStore: Sendable {
    static let service = "io.github.jonasnowak.dms.github"
    static let account = "access-token"

    static func save(token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// GitHub Sign-In + live notifications tracker backing the `github-notifications`
/// plugin bar widget and the DankBar GitHub popout.
///
/// Two authentication methods are supported:
/// - **Keychain token**: a user-created fine-grained PAT stored in the macOS Keychain
///   (`io.github.jonasnowak.dms.github` / `access-token`). Fetching uses `URLSession`
///   directly against `https://api.github.com` with a `Bearer` token — zero CLI deps.
/// - **gh CLI**: automatic fallback when the `gh` binary is installed and authenticated;
///   fetching goes through `gh api` via `SafeProcessRunner`.
///
/// Polls every 60s while `start()` is active; `stop()` cancels the timer immediately.
@MainActor
public final class GitHubNotificationsService: ObservableObject {
    public static let shared = GitHubNotificationsService()

    @Published public private(set) var isAvailable: Bool = false
    @Published public private(set) var isSignedIn: Bool = false
    @Published public private(set) var authMethod: GitHubAuthMethod = .none
    @Published public private(set) var username: String? = nil
    @Published public private(set) var unreadCount: Int = 0
    @Published public private(set) var notifications: [GitHubNotificationItem] = []
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var isAuthenticating: Bool = false
    @Published public private(set) var authError: String? = nil
    @Published public private(set) var lastUpdated: Date? = nil

    private static let candidateBinaryPaths = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        "/usr/bin/gh"
    ]

    private static let pollInterval: TimeInterval = 60.0
    private static let apiBase = "https://api.github.com"
    private static let notificationsURL = "https://github.com/notifications"

    private var timer: Timer?
    /// Set when the user explicitly signs out so gh CLI auto-detection does not
    /// silently re-sign them in until they click "Use gh CLI".
    private var signedOutExplicitly: Bool = false
    private var keychainToken: String?

    private var binaryPath: String? {
        Self.candidateBinaryPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private init() {
        restoreSavedSession()
    }

    // MARK: - Lifecycle

    public func start() {
        isEnabled = true
        if !isSignedIn && keychainToken == nil && !signedOutExplicitly {
            Task { await detectGHCLIAuth() }
        }
        refresh()
        startTimer()
    }

    public func stop() {
        isEnabled = false
        timer?.invalidate()
        timer = nil
    }

    /// Re-fetches notifications for the active auth method.
    public func refresh() {
        switch authMethod {
        case .keychainToken:
            guard let token = keychainToken else {
                isAvailable = false
                return
            }
            isAvailable = true
            fetchNotificationsWithToken(token)
        case .ghCLI:
            guard let path = binaryPath else {
                isAvailable = false
                return
            }
            isAvailable = true
            fetchNotificationsWithGHCLI(path: path)
        case .none:
            if !signedOutExplicitly {
                Task { await detectGHCLIAuth() }
            } else {
                isAvailable = false
            }
        }
    }

    public func openNotifications() {
        guard let url = URL(string: Self.notificationsURL) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Session restore

    /// On init: silently load a saved Keychain token; if none and the user has not
    /// explicitly signed out, try gh CLI auto-detection.
    private func restoreSavedSession() {
        if let token = GitHubKeychainStore.load(), !token.isEmpty {
            keychainToken = token
            authMethod = .keychainToken
            isSignedIn = true
            isAvailable = true
            Task { await validateStoredToken() }
        } else {
            Task { await detectGHCLIAuth() }
        }
    }

    /// Validates the stored Keychain token against `GET /user` to recover the username.
    private func validateStoredToken() async {
        guard let token = keychainToken else { return }
        do {
            let (data, response) = try await Self.apiData(path: "/user", method: "GET", token: token)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let profile = GitHubNotificationParser.parseUserProfile(from: data) {
                username = profile.login
            }
        } catch {
            // Silent: the token may still be valid; refresh() will surface errors.
        }
    }

    // MARK: - Auth flows

    /// Validates a user-pasted token against `GET /user` and, on 200 OK, stores it in
    /// the macOS Keychain and immediately refreshes notifications.
    public func signInWithToken(_ rawToken: String) async {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            authError = "Paste a GitHub token first (ghp_... or github_pat_...)."
            return
        }
        isAuthenticating = true
        authError = nil
        defer { isAuthenticating = false }
        signedOutExplicitly = false
        do {
            let (data, response) = try await Self.apiData(path: "/user", method: "GET", token: token)
            guard let http = response as? HTTPURLResponse else {
                authError = "Network error: no HTTP response from api.github.com."
                return
            }
            switch http.statusCode {
            case 200:
                guard let profile = GitHubNotificationParser.parseUserProfile(from: data) else {
                    authError = "Could not parse the GitHub user profile response."
                    return
                }
                keychainToken = token
                _ = GitHubKeychainStore.save(token: token)
                authMethod = .keychainToken
                isSignedIn = true
                isAvailable = true
                username = profile.login
                authError = nil
                refresh()
            case 401:
                authError = "GitHub rejected the token (401). Use a token with scopes: notifications, read:user."
            default:
                authError = "GitHub returned HTTP \(http.statusCode) while validating the token."
            }
        } catch {
            authError = "Network error: \(error.localizedDescription)"
        }
    }

    /// Detects an installed & authenticated `gh` CLI and adopts it as the auth method.
    public func detectGHCLIAuth() async {
        guard let path = binaryPath else {
            if !isSignedIn {
                isAvailable = false
            }
            return
        }
        let tokenResult = await Task.detached {
            SafeProcessRunner.run(executablePath: path, arguments: ["auth", "token"], timeout: 5.0)
        }.value
        guard let tokenOutput = try? tokenResult.get(), !tokenOutput.timedOut,
              let token = String(data: tokenOutput.stdout, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return
        }
        let userResult = await Task.detached {
            SafeProcessRunner.run(executablePath: path, arguments: ["api", "user", "--jq", ".login"], timeout: 6.0)
        }.value
        let login = (try? userResult.get()).flatMap {
            String(data: $0.stdout, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let login, !login.isEmpty else { return }
        signedOutExplicitly = false
        authMethod = .ghCLI
        isSignedIn = true
        isAvailable = true
        username = login
        authError = nil
        refresh()
    }

    /// Opens Terminal running `gh auth login --web` (or https://cli.github.com when
    /// gh is not installed) and shows a ToastCenter hint.
    public func launchGHCLIWebLogin() {
        if let path = binaryPath {
            let command = "\(path) auth login --web -h github.com -s notifications"
            let escaped = command
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let script = "tell application \"Terminal\" to do script \"\(escaped); echo; echo 'Press Enter to close...'; read\""
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            if error != nil {
                NSWorkspace.shared.open(URL(string: "https://cli.github.com")!)
            }
            ToastCenter.shared.show(
                icon: "terminal.fill",
                message: "Finish 'gh auth login' in Terminal, then click 'Use gh CLI'"
            )
        } else {
            if let url = URL(string: "https://cli.github.com") {
                NSWorkspace.shared.open(url)
            }
            ToastCenter.shared.show(
                icon: "terminal.fill",
                message: "Install GitHub CLI first, then run: gh auth login --web -h github.com -s notifications"
            )
        }
    }

    /// Opens the GitHub "new token" page pre-scoped for notifications in the default browser.
    public func openCreateTokenPage() {
        guard let url = URL(string: "https://github.com/settings/tokens/new?scopes=notifications,read:user&description=DankMacShell%20Notifications") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Deletes the Keychain item and resets all session state. Sets `signedOutExplicitly`
    /// so gh CLI auto-detection stays off until the user clicks "Use gh CLI".
    public func signOut() {
        GitHubKeychainStore.delete()
        keychainToken = nil
        signedOutExplicitly = true
        authMethod = .none
        isSignedIn = false
        isAvailable = false
        username = nil
        notifications = []
        unreadCount = 0
        authError = nil
    }

    // MARK: - Notification actions

    /// Marks a single thread as read (PATCH) and optimistically removes it locally.
    public func markAsRead(threadID: String) {
        if let index = notifications.firstIndex(where: { $0.id == threadID }) {
            let wasUnread = notifications[index].unread
            notifications.remove(at: index)
            if wasUnread {
                unreadCount = max(0, unreadCount - 1)
            }
        }
        Task { await performMarkAsRead(threadID: threadID) }
    }

    /// Marks all notifications as read (PUT) and clears the local list.
    public func markAllAsRead() {
        notifications = []
        unreadCount = 0
        Task { await performMarkAllAsRead() }
    }

    /// Opens the notification's web URL and marks it as read when still unread.
    public func openNotification(_ item: GitHubNotificationItem) {
        if let url = URL(string: item.htmlURLString) {
            NSWorkspace.shared.open(url)
        }
        if item.unread {
            markAsRead(threadID: item.id)
        }
    }

    // MARK: - Fetching

    private func fetchNotificationsWithToken(_ token: String) {
        Task.detached(priority: .utility) { [weak self] in
            let result: Result<(Data, URLResponse), Error>
            do {
                result = .success(try await Self.apiData(path: "/notifications?per_page=25", method: "GET", token: token))
            } catch {
                result = .failure(error)
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let (data, response)):
                    if let http = response as? HTTPURLResponse {
                        switch http.statusCode {
                        case 200:
                            self.applyNotificationsData(data)
                            self.authError = nil
                        case 401:
                            self.authError = "GitHub rejected the stored token (401). Sign in again."
                        default:
                            self.authError = "GitHub returned HTTP \(http.statusCode)."
                        }
                    }
                case .failure(let error):
                    self.authError = "Network error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func fetchNotificationsWithGHCLI(path: String) {
        Task.detached(priority: .utility) { [weak self] in
            let result = SafeProcessRunner.run(
                executablePath: path,
                arguments: ["api", "notifications?per_page=25", "--jq", "."],
                timeout: 8.0
            )
            Task { @MainActor [weak self] in
                guard let output = try? result.get(), !output.timedOut else { return }
                self?.applyNotificationsData(output.stdout)
            }
        }
    }

    private func applyNotificationsData(_ data: Data) {
        let items = GitHubNotificationParser.parseNotifications(from: data)
        notifications = items
        unreadCount = items.filter { $0.unread }.count
        lastUpdated = Date()
    }

    private func performMarkAsRead(threadID: String) async {
        switch authMethod {
        case .keychainToken:
            guard let token = keychainToken else { return }
            _ = try? await Self.apiData(path: "/notifications/threads/\(threadID)", method: "PATCH", token: token)
        case .ghCLI:
            guard let path = binaryPath else { return }
            _ = await Task.detached {
                SafeProcessRunner.run(
                    executablePath: path,
                    arguments: ["api", "-X", "PATCH", "notifications/threads/\(threadID)"],
                    timeout: 8.0
                )
            }.value
        case .none:
            break
        }
    }

    private func performMarkAllAsRead() async {
        switch authMethod {
        case .keychainToken:
            guard let token = keychainToken else { return }
            _ = try? await Self.apiData(path: "/notifications", method: "PUT", token: token)
        case .ghCLI:
            guard let path = binaryPath else { return }
            _ = await Task.detached {
                SafeProcessRunner.run(
                    executablePath: path,
                    arguments: ["api", "-X", "PUT", "notifications"],
                    timeout: 8.0
                )
            }.value
        case .none:
            break
        }
    }

    // MARK: - HTTP helper

    /// Builds a `URLRequest` for the GitHub REST API with the required headers.
    private static func apiRequest(path: String, method: String, token: String) -> URLRequest {
        var request = URLRequest(url: URL(string: apiBase + path)!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(DMSVersion.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 15
        return request
    }

    /// Performs a GitHub REST API request with a Bearer token.
    private static func apiData(path: String, method: String, token: String) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: apiRequest(path: path, method: method, token: token))
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }
}
