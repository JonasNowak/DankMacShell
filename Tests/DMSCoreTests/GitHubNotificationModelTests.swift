import Testing
import Foundation
@testable import DMSCore

@Suite("GitHub Auth & Notification Model Tests")
struct GitHubNotificationModelTests {

    // MARK: - parseNotifications

    @Test("parseNotifications decodes a full REST /notifications payload")
    func testParseNotificationsFullPayload() {
        let json = """
        [
          {
            "id": "123456",
            "unread": true,
            "reason": "mention",
            "updated_at": "2025-06-01T12:34:56Z",
            "repository": {
              "full_name": "octocat/hello-world",
              "html_url": "https://github.com/octocat/hello-world"
            },
            "subject": {
              "title": "Fix the thing",
              "type": "Issue",
              "url": "https://api.github.com/repos/octocat/hello-world/issues/42"
            }
          },
          {
            "id": "789",
            "unread": false,
            "reason": "review_requested",
            "updated_at": "2025-06-02T08:00:00Z",
            "repository": {
              "full_name": "octocat/hello-world",
              "html_url": "https://github.com/octocat/hello-world"
            },
            "subject": {
              "title": "Add feature",
              "type": "PullRequest",
              "url": "https://api.github.com/repos/octocat/hello-world/pulls/7"
            }
          }
        ]
        """.data(using: .utf8)!

        let items = GitHubNotificationParser.parseNotifications(from: json)

        #expect(items.count == 2)

        let first = items[0]
        #expect(first.id == "123456")
        #expect(first.title == "Fix the thing")
        #expect(first.repositoryFullName == "octocat/hello-world")
        #expect(first.reason == "mention")
        #expect(first.subjectType == "Issue")
        #expect(first.unread == true)
        #expect(first.updatedAt == "2025-06-01T12:34:56Z")
        #expect(first.htmlURLString == "https://github.com/octocat/hello-world/issues/42")

        let second = items[1]
        #expect(second.id == "789")
        #expect(second.unread == false)
        #expect(second.subjectType == "PullRequest")
        #expect(second.htmlURLString == "https://github.com/octocat/hello-world/pull/7")
    }

    @Test("parseNotifications returns empty array for invalid JSON")
    func testParseNotificationsInvalidJSON() {
        #expect(GitHubNotificationParser.parseNotifications(from: Data("not json".utf8)).isEmpty)
        #expect(GitHubNotificationParser.parseNotifications(from: Data("{\"a\":1}".utf8)).isEmpty)
        #expect(GitHubNotificationParser.parseNotifications(from: Data()).isEmpty)
    }

    @Test("parseNotifications skips entries without an id and fills defaults")
    func testParseNotificationsMissingFields() {
        let json = """
        [
          {"unread": true},
          {"id": "1", "subject": {"title": "T", "type": "Release"}}
        ]
        """.data(using: .utf8)!

        let items = GitHubNotificationParser.parseNotifications(from: json)

        #expect(items.count == 1)
        #expect(items[0].id == "1")
        #expect(items[0].title == "T")
        #expect(items[0].repositoryFullName == "")
        #expect(items[0].reason == "")
        #expect(items[0].unread == false)
        #expect(items[0].htmlURLString == "https://github.com/notifications")
    }

    // MARK: - webURL conversion

    @Test("webURL converts pulls API URL to web pull URL")
    func testWebURLPullRequest() {
        let url = GitHubNotificationParser.webURL(
            fromSubjectAPIURL: "https://api.github.com/repos/octocat/hello-world/pulls/7",
            repositoryHTMLURL: "https://github.com/octocat/hello-world",
            subjectType: "PullRequest"
        )
        #expect(url == "https://github.com/octocat/hello-world/pull/7")
    }

    @Test("webURL keeps issues path")
    func testWebURLIssue() {
        let url = GitHubNotificationParser.webURL(
            fromSubjectAPIURL: "https://api.github.com/repos/a/b/issues/123",
            repositoryHTMLURL: "https://github.com/a/b",
            subjectType: "Issue"
        )
        #expect(url == "https://github.com/a/b/issues/123")
    }

    @Test("webURL converts commits sha to commit page")
    func testWebURLCommit() {
        let url = GitHubNotificationParser.webURL(
            fromSubjectAPIURL: "https://api.github.com/repos/a/b/commits/deadbeefcafe",
            repositoryHTMLURL: "https://github.com/a/b",
            subjectType: "Commit"
        )
        #expect(url == "https://github.com/a/b/commit/deadbeefcafe")
    }

    @Test("webURL converts releases to releases page")
    func testWebURLRelease() {
        let url = GitHubNotificationParser.webURL(
            fromSubjectAPIURL: "https://api.github.com/repos/a/b/releases/987",
            repositoryHTMLURL: "https://github.com/a/b",
            subjectType: "Release"
        )
        #expect(url == "https://github.com/a/b/releases")
    }

    @Test("webURL keeps discussions path")
    func testWebURLDiscussion() {
        let url = GitHubNotificationParser.webURL(
            fromSubjectAPIURL: "https://api.github.com/repos/a/b/discussions/5",
            repositoryHTMLURL: "https://github.com/a/b",
            subjectType: "Discussion"
        )
        #expect(url == "https://github.com/a/b/discussions/5")
    }

    @Test("webURL falls back to repository HTML URL when subject URL is missing")
    func testWebURLFallbackToRepository() {
        let url = GitHubNotificationParser.webURL(
            fromSubjectAPIURL: nil,
            repositoryHTMLURL: "https://github.com/a/b",
            subjectType: "Issue"
        )
        #expect(url == "https://github.com/a/b")
    }

    @Test("webURL falls back to notifications page when nothing is available")
    func testWebURLFallbackToNotifications() {
        let url = GitHubNotificationParser.webURL(
            fromSubjectAPIURL: nil,
            repositoryHTMLURL: nil,
            subjectType: "Issue"
        )
        #expect(url == "https://github.com/notifications")

        let url2 = GitHubNotificationParser.webURL(
            fromSubjectAPIURL: "https://example.com/something",
            repositoryHTMLURL: nil,
            subjectType: "CheckSuite"
        )
        #expect(url2 == "https://github.com/notifications")
    }

    // MARK: - parseUserProfile

    @Test("parseUserProfile decodes login, name, and avatar")
    func testParseUserProfile() {
        let json = """
        {"login": "octocat", "name": "The Octocat", "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4"}
        """.data(using: .utf8)!

        let profile = GitHubNotificationParser.parseUserProfile(from: json)

        #expect(profile != nil)
        #expect(profile?.login == "octocat")
        #expect(profile?.name == "The Octocat")
        #expect(profile?.avatarURL == "https://avatars.githubusercontent.com/u/583231?v=4")
    }

    @Test("parseUserProfile handles null name and missing avatar")
    func testParseUserProfileOptionalFields() {
        let json = """
        {"login": "monalisa", "name": null}
        """.data(using: .utf8)!

        let profile = GitHubNotificationParser.parseUserProfile(from: json)

        #expect(profile?.login == "monalisa")
        #expect(profile?.name == nil)
        #expect(profile?.avatarURL == nil)
    }

    @Test("parseUserProfile returns nil for invalid payloads")
    func testParseUserProfileInvalid() {
        #expect(GitHubNotificationParser.parseUserProfile(from: Data("nope".utf8)) == nil)
        #expect(GitHubNotificationParser.parseUserProfile(from: Data("{\"name\":\"x\"}".utf8)) == nil)
        #expect(GitHubNotificationParser.parseUserProfile(from: Data()) == nil)
    }

    // MARK: - sfSymbol mapping

    @Test("sfSymbol maps subject types to SF Symbols")
    func testSFSymbolMapping() {
        #expect(GitHubNotificationParser.sfSymbol(forSubjectType: "PullRequest") == "arrow.triangle.pull")
        #expect(GitHubNotificationParser.sfSymbol(forSubjectType: "Issue") == "exclamationmark.circle")
        #expect(GitHubNotificationParser.sfSymbol(forSubjectType: "Release") == "tag")
        #expect(GitHubNotificationParser.sfSymbol(forSubjectType: "Discussion") == "bubble.left.and.bubble.right")
        #expect(GitHubNotificationParser.sfSymbol(forSubjectType: "CheckSuite") == "checkmark.seal")
        #expect(GitHubNotificationParser.sfSymbol(forSubjectType: "Commit") == "bell.fill")
        #expect(GitHubNotificationParser.sfSymbol(forSubjectType: "") == "bell.fill")
        #expect(GitHubNotificationParser.sfSymbol(forSubjectType: "Whatever") == "bell.fill")
    }

    // MARK: - Model conformances

    @Test("GitHubAuthMethod raw values and Codable round-trip")
    func testAuthMethodCodable() throws {
        #expect(GitHubAuthMethod.none.rawValue == "none")
        #expect(GitHubAuthMethod.keychainToken.rawValue == "keychainToken")
        #expect(GitHubAuthMethod.ghCLI.rawValue == "ghCLI")

        let encoded = try JSONEncoder().encode(GitHubAuthMethod.ghCLI)
        let decoded = try JSONDecoder().decode(GitHubAuthMethod.self, from: encoded)
        #expect(decoded == .ghCLI)
    }

    @Test("GitHubNotificationItem Codable round-trip and Identifiable")
    func testNotificationItemCodable() throws {
        let item = GitHubNotificationItem(
            id: "42",
            title: "Hello",
            repositoryFullName: "a/b",
            reason: "assign",
            subjectType: "Issue",
            unread: true,
            updatedAt: "2025-01-01T00:00:00Z",
            htmlURLString: "https://github.com/a/b/issues/1"
        )
        let encoded = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(GitHubNotificationItem.self, from: encoded)
        #expect(decoded == item)
        #expect(decoded.id == item.id)
    }

    @Test("GitHubUserProfile Codable round-trip")
    func testUserProfileCodable() throws {
        let profile = GitHubUserProfile(login: "octocat", name: "The Octocat", avatarURL: "https://example.com/a.png")
        let encoded = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(GitHubUserProfile.self, from: encoded)
        #expect(decoded == profile)
    }
}
