import Foundation

/// Authentication method used by the GitHub notifications tracker.
public enum GitHubAuthMethod: String, Codable, Sendable, Equatable {
    case none
    case keychainToken
    case ghCLI
}

/// A single GitHub notification thread (REST API `/notifications` entry), flattened
/// into a pure-logic, Sendable model for the DankBar popout and settings UI.
public struct GitHubNotificationItem: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var repositoryFullName: String
    public var reason: String
    public var subjectType: String
    public var unread: Bool
    public var updatedAt: String
    public var htmlURLString: String

    public init(
        id: String,
        title: String,
        repositoryFullName: String,
        reason: String,
        subjectType: String,
        unread: Bool,
        updatedAt: String,
        htmlURLString: String
    ) {
        self.id = id
        self.title = title
        self.repositoryFullName = repositoryFullName
        self.reason = reason
        self.subjectType = subjectType
        self.unread = unread
        self.updatedAt = updatedAt
        self.htmlURLString = htmlURLString
    }
}

/// GitHub REST API `/user` profile subset.
public struct GitHubUserProfile: Codable, Sendable, Equatable {
    public var login: String
    public var name: String?
    public var avatarURL: String?

    public init(login: String, name: String? = nil, avatarURL: String? = nil) {
        self.login = login
        self.name = name
        self.avatarURL = avatarURL
    }
}

/// Pure, dependency-free helpers for decoding GitHub REST API payloads and
/// converting API subject URLs into human-facing `github.com` web URLs.
public enum GitHubNotificationParser: Sendable {

    private static let apiReposPrefix = "https://api.github.com/repos/"
    private static let webBase = "https://github.com/"
    private static let fallbackURL = "https://github.com/notifications"

    // MARK: - Notifications

    /// Decodes the JSON array returned by `GET /notifications` into flat items.
    /// Each item's `htmlURLString` is derived via `webURL(fromSubjectAPIURL:...)`.
    public static func parseNotifications(from data: Data) -> [GitHubNotificationItem] {
        guard let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return []
        }
        var items: [GitHubNotificationItem] = []
        items.reserveCapacity(array.count)
        for entry in array {
            guard let id = entry["id"] as? String else { continue }
            let unread = entry["unread"] as? Bool ?? false
            let reason = entry["reason"] as? String ?? ""
            let updatedAt = entry["updated_at"] as? String ?? ""
            let repository = entry["repository"] as? [String: Any]
            let repositoryFullName = repository?["full_name"] as? String ?? ""
            let repositoryHTMLURL = repository?["html_url"] as? String
            let subject = entry["subject"] as? [String: Any]
            let title = subject?["title"] as? String ?? ""
            let subjectType = subject?["type"] as? String ?? ""
            let subjectURL = subject?["url"] as? String
            let htmlURLString = webURL(
                fromSubjectAPIURL: subjectURL,
                repositoryHTMLURL: repositoryHTMLURL,
                subjectType: subjectType
            )
            items.append(GitHubNotificationItem(
                id: id,
                title: title,
                repositoryFullName: repositoryFullName,
                reason: reason,
                subjectType: subjectType,
                unread: unread,
                updatedAt: updatedAt,
                htmlURLString: htmlURLString
            ))
        }
        return items
    }

    // MARK: - Web URL conversion

    /// Converts a subject API URL (`https://api.github.com/repos/{owner}/{repo}/...`)
    /// into the corresponding `https://github.com/...` web URL:
    /// - `/pulls/{n}` → `/pull/{n}`
    /// - `/issues/{n}` → `/issues/{n}`
    /// - `/commits/{sha}` → `/commit/{sha}`
    /// - `/releases/{id}` → `/releases`
    /// - `/discussions/{n}` → `/discussions/{n}`
    /// Falls back to `repositoryHTMLURL`, then to `https://github.com/notifications`.
    public static func webURL(
        fromSubjectAPIURL subjectAPIURL: String?,
        repositoryHTMLURL: String?,
        subjectType: String
    ) -> String {
        if let subjectAPIURL, subjectAPIURL.hasPrefix(apiReposPrefix) {
            let remainder = String(subjectAPIURL.dropFirst(apiReposPrefix.count))
            let segments = remainder.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            // segments: [owner, repo, kind, number, ...]
            guard segments.count >= 4 else {
                return repositoryHTMLURL ?? fallbackURL
            }
            let owner = segments[0]
            let repo = segments[1]
            let kind = segments[2]
            let number = segments[3]
            let repoWeb = webBase + owner + "/" + repo
            switch kind {
            case "pulls":
                return repoWeb + "/pull/" + number
            case "issues":
                return repoWeb + "/issues/" + number
            case "commits":
                return repoWeb + "/commit/" + number
            case "releases":
                return repoWeb + "/releases"
            case "discussions":
                return repoWeb + "/discussions/" + number
            default:
                // Unknown subject kind: keep the repo page as the safest target.
                return repositoryHTMLURL ?? repoWeb
            }
        }
        // subjectType hint when no usable API URL was provided.
        if subjectAPIURL == nil, let repositoryHTMLURL, !repositoryHTMLURL.isEmpty {
            return repositoryHTMLURL
        }
        return repositoryHTMLURL ?? fallbackURL
    }

    // MARK: - User profile

    /// Decodes the JSON object returned by `GET /user`. Returns `nil` on any decode failure.
    public static func parseUserProfile(from data: Data) -> GitHubUserProfile? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let login = object["login"] as? String else {
            return nil
        }
        let name = object["name"] as? String
        let avatarURL = object["avatar_url"] as? String
        return GitHubUserProfile(login: login, name: name, avatarURL: avatarURL)
    }

    // MARK: - SF Symbols

    /// Maps a GitHub notification subject type to an SF Symbol name.
    public static func sfSymbol(forSubjectType subjectType: String) -> String {
        switch subjectType {
        case "PullRequest":
            return "arrow.triangle.pull"
        case "Issue":
            return "exclamationmark.circle"
        case "Release":
            return "tag"
        case "Discussion":
            return "bubble.left.and.bubble.right"
        case "CheckSuite":
            return "checkmark.seal"
        default:
            return "bell.fill"
        }
    }
}
