import Foundation

/// Represents an application with an active window in a workspace.
public struct WorkspaceAppItem: Identifiable, Equatable, Sendable {
    public var id: String {
        if let winId = omniWMWindowID, !winId.isEmpty {
            return winId
        }
        return "\(pid)_\(bundleID)"
    }
    public let pid: pid_t
    public let name: String
    public let bundleID: String
    public let path: String
    public let isActive: Bool
    public let omniWMWindowID: String?

    public init(pid: pid_t, name: String, bundleID: String, path: String, isActive: Bool = false, omniWMWindowID: String? = nil) {
        self.pid = pid
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.isActive = isActive
        self.omniWMWindowID = omniWMWindowID
    }
}

/// Information describing a workspace (virtual tiling or native macOS space).
public struct WorkspaceInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let number: Int
    public let name: String
    public let isCurrent: Bool
    public let apps: [WorkspaceAppItem]

    public init(id: String, number: Int, name: String, isCurrent: Bool, apps: [WorkspaceAppItem] = []) {
        self.id = id
        self.number = number
        self.name = name
        self.isCurrent = isCurrent
        self.apps = apps
    }
}
