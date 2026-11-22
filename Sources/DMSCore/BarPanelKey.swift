import Foundation

/// Stable identity for one DankBar panel instance.
///
/// Keying panels by `NSScreen.screens` array index is volatile: the index of a given
/// physical display changes whenever monitors are reordered, disconnected, or woken
/// from sleep. `CGDirectDisplayID` (exposed here as `UInt32` so DMSCore stays free of
/// AppKit/CoreGraphics) is stable for the lifetime of a display connection, so it is
/// the correct primary key. The bar config id and edge position disambiguate multiple
/// bars hosted on the same display.
public struct BarPanelKey: Hashable, Sendable, Equatable {
    /// Stable CoreGraphics display identifier (`CGDirectDisplayID`); 0 when unknown.
    public let displayID: UInt32
    /// `BarConfig.id` of the bar instance this panel renders.
    public let configID: String
    /// Edge position: "top", "bottom", "left", or "right".
    public let position: String

    public init(displayID: UInt32, configID: String, position: String) {
        self.displayID = displayID
        self.configID = configID
        self.position = position
    }

    /// Serialized form: `"<displayID>|<position>|<configID>"`.
    ///
    /// The config id is placed last and parsing splits on at most two separators, so
    /// underscores, hyphens, spaces, or even `|` characters inside a config id can
    /// never collide with or corrupt the display id / position fields.
    public var rawKey: String {
        "\(displayID)|\(position)|\(configID)"
    }

    /// Parses a `rawKey` produced by `rawKey`, plus the legacy
    /// `"<screenIndex>_<configID>_<position>"` format, back into a key.
    /// Returns nil for malformed input.
    public init?(rawKey: String) {
        if rawKey.contains("|") {
            // New format: displayID|position|configID — configID last, so it may itself
            // contain '|' without breaking the parse (maxSplits: 2 keeps the remainder).
            let parts = rawKey.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3,
                  let displayID = UInt32(parts[0]),
                  !parts[1].isEmpty,
                  !parts[2].isEmpty else { return nil }
            self.displayID = displayID
            self.position = String(parts[1])
            self.configID = String(parts[2])
        } else {
            // Legacy format: <screenIndex>_<configID>_<position> — the config id sits
            // between the first and last underscore, so underscores inside it survive.
            guard let firstUnderscore = rawKey.firstIndex(of: "_") else { return nil }
            let rest = rawKey[rawKey.index(after: firstUnderscore)...]
            guard let lastUnderscore = rest.lastIndex(of: "_") else { return nil }
            guard let legacyIndex = UInt32(rawKey[..<firstUnderscore]) else { return nil }
            let configID = rest[..<lastUnderscore]
            let position = rest[rest.index(after: lastUnderscore)...]
            guard !configID.isEmpty, !position.isEmpty else { return nil }
            // Legacy keys carried the volatile array index rather than a display id;
            // keep it as the best available identity so old keys still parse cleanly
            // instead of being dropped.
            self.displayID = legacyIndex
            self.configID = String(configID)
            self.position = String(position)
        }
    }
}
