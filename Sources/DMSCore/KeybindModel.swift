import Foundation

/// A single configurable DMS global hotkey binding, normalized for conflict detection.
public struct DMSHotkeyBinding: Identifiable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var key: String
    public var modifiers: [String]
    public var isEnabled: Bool

    public init(id: String, title: String, key: String, modifiers: [String], isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.key = key
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }
}

/// A detected conflict where two or more enabled bindings share the same key+modifiers signature.
public struct KeybindConflict: Sendable, Equatable {
    public var signature: String
    public var bindingIDs: [String]
    public var displayKeys: String

    public init(signature: String, bindingIDs: [String], displayKeys: String) {
        self.signature = signature
        self.bindingIDs = bindingIDs
        self.displayKeys = displayKeys
    }
}

/// Detects keybind conflicts between enabled DMS hotkey bindings.
/// Normalization: lowercased key + sorted lowercased modifiers; disabled bindings and
/// empty keys are ignored. A conflict exists wherever >= 2 enabled bindings share the
/// exact same normalized signature.
public enum KeybindConflictDetector: Sendable {

    /// Normalized `modifiers|key` signature used for conflict grouping.
    public static func normalizedSignature(key: String, modifiers: [String]) -> String {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedModifiers = modifiers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .sorted()
        return normalizedModifiers.joined(separator: "+") + "|" + normalizedKey
    }

    /// Returns one conflict per signature shared by at least two enabled bindings.
    public static func findConflicts(in bindings: [DMSHotkeyBinding]) -> [KeybindConflict] {
        var groups: [String: [DMSHotkeyBinding]] = [:]
        for binding in bindings {
            guard binding.isEnabled else { continue }
            let key = binding.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            let signature = normalizedSignature(key: binding.key, modifiers: binding.modifiers)
            groups[signature, default: []].append(binding)
        }

        var conflicts: [KeybindConflict] = []
        for (signature, group) in groups where group.count >= 2 {
            let ids = group.map { $0.id }.sorted()
            let displays = Array(Set(group.map {
                HotkeyHelper.displayString(key: $0.key, modifiers: $0.modifiers.joined(separator: "+"))
            })).sorted()
            conflicts.append(KeybindConflict(
                signature: signature,
                bindingIDs: ids,
                displayKeys: displays.joined(separator: "  •  ")
            ))
        }
        return conflicts.sorted { $0.signature < $1.signature }
    }
}

/// A single keybind imported from OmniWM's `~/.config/omniwm/settings.toml`.
public struct OmniWMKeybindEntry: Identifiable, Sendable, Equatable {
    public var id: String
    public var action: String
    public var keys: String
    public var category: String

    public init(id: String, action: String, keys: String, category: String) {
        self.id = id
        self.action = action
        self.keys = keys
        self.category = category
    }
}

/// Clean string-based parser for the keybind sections of OmniWM's `settings.toml`.
/// Supports `[keybinds]` / `[bindings]` tables with `name = "mod+key"` lines as well as
/// `[[keybinds]]` array-of-tables with `key = "..."` + `action = "..."` pairs.
/// Uses plain string scanning only — no Swift 6 bare regex literals.
public enum OmniWMKeybindParser: Sendable {

    public static func parse(toml: String) -> [OmniWMKeybindEntry] {
        var entries: [OmniWMKeybindEntry] = []
        var inKeybindSection = false
        var pendingKeys: String? = nil
        var pendingAction: String? = nil

        func flushPending() {
            if let action = pendingAction, let keys = pendingKeys {
                entries.append(makeEntry(action: action, keys: keys, index: entries.count))
            }
            pendingKeys = nil
            pendingAction = nil
        }

        for rawLine in toml.components(separatedBy: .newlines) {
            let line = stripComment(from: rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("[") {
                flushPending()
                inKeybindSection = isKeybindSection(sectionName(from: line))
                continue
            }

            guard inKeybindSection, let (name, value) = parseKeyValue(line) else { continue }
            let lowerName = name.lowercased()

            if lowerName == "key" || lowerName == "keys" {
                pendingKeys = formatKeys(value)
            } else if lowerName == "action" || lowerName == "command" || lowerName == "cmd" {
                pendingAction = value
            } else {
                // `focus-left = "alt+h"` style: the key name is the action, the value is the combo.
                entries.append(makeEntry(action: name, keys: formatKeys(value), index: entries.count))
                continue
            }

            if pendingKeys != nil && pendingAction != nil {
                flushPending()
            }
        }
        flushPending()
        return entries
    }

    // MARK: - Line helpers

    /// Removes a trailing `#` comment, ignoring `#` characters inside quoted strings.
    private static func stripComment(from line: String) -> String {
        var inQuotes = false
        for (offset, char) in line.enumerated() {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "#" && !inQuotes {
                return String(line.prefix(offset))
            }
        }
        return line
    }

    /// Extracts the section name from a `[table]` or `[[array-table]]` header line.
    private static func sectionName(from line: String) -> String {
        var name = line
        if name.hasPrefix("[[") {
            name = String(name.dropFirst(2))
            if name.hasSuffix("]]") { name = String(name.dropLast(2)) }
        } else if name.hasPrefix("[") {
            name = String(name.dropFirst(1))
            if name.hasSuffix("]") { name = String(name.dropLast(1)) }
        }
        return name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private static func isKeybindSection(_ name: String) -> Bool {
        return name == "keybinds" || name == "bindings"
            || name.contains("keybind") || name.contains("binding")
    }

    /// Splits `name = value`, stripping surrounding quotes from the value.
    private static func parseKeyValue(_ line: String) -> (name: String, value: String)? {
        guard let eq = line.firstIndex(of: "=") else { return nil }
        let name = line[..<eq].trimmingCharacters(in: .whitespaces)
        var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        if value.count >= 2 {
            let first = value.first!
            let last = value.last!
            if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                value = String(value.dropFirst().dropLast())
            }
        }
        guard !name.isEmpty else { return nil }
        return (name, value)
    }

    // MARK: - Key formatting

    /// Formats a TOML keybind value (`"alt+h"` or `["alt+h", "alt+j"]`) into clean symbols.
    private static func formatKeys(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[") {
            return quotedStrings(in: trimmed)
                .map { formatCombo($0) }
                .joined(separator: " / ")
        }
        return formatCombo(trimmed)
    }

    /// Extracts all double-quoted substrings from a TOML array literal.
    private static func quotedStrings(in text: String) -> [String] {
        var result: [String] = []
        var current: String? = nil
        for char in text {
            if char == "\"" {
                if let open = current {
                    result.append(open)
                    current = nil
                } else {
                    current = ""
                }
            } else if current != nil {
                current! += String(char)
            }
        }
        return result
    }

    /// Formats one combo like `cmd+shift+4` into `⌘⇧ 4`.
    private static func formatCombo(_ combo: String) -> String {
        let tokens = combo
            .split(separator: "+", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        var control = false
        var option = false
        var shift = false
        var command = false
        var keyToken: String? = nil

        for token in tokens {
            switch token {
            case "ctrl", "control", "⌃":
                control = true
            case "alt", "option", "opt", "⌥":
                option = true
            case "shift", "⇧":
                shift = true
            case "cmd", "command", "super", "win", "meta", "logo", "⌘":
                command = true
            default:
                keyToken = token
            }
        }

        var symbols = ""
        if control { symbols += "⌃" }
        if option { symbols += "⌥" }
        if shift { symbols += "⇧" }
        if command { symbols += "⌘" }

        let keyDisplay = keyDisplayName(keyToken ?? "")
        return symbols.isEmpty ? keyDisplay : "\(symbols) \(keyDisplay)"
    }

    private static func keyDisplayName(_ key: String) -> String {
        switch key {
        case "space": return "Space"
        case "return", "enter": return "↵"
        case "tab": return "⇥"
        case "escape", "esc": return "Esc"
        case "delete", "backspace": return "⌫"
        case "left", "leftarrow": return "←"
        case "right", "rightarrow": return "→"
        case "up", "uparrow": return "↑"
        case "down", "downarrow": return "↓"
        case "backslash", "\\": return "\\"
        case "slash", "/": return "/"
        case "grave", "backtick", "`": return "`"
        case "": return ""
        default:
            return key.count == 1 ? key.uppercased() : key.capitalized
        }
    }

    // MARK: - Entry construction

    private static func makeEntry(action: String, keys: String, index: Int) -> OmniWMKeybindEntry {
        OmniWMKeybindEntry(
            id: "omniwm-\(index)-\(action.lowercased())",
            action: action,
            keys: keys,
            category: category(for: action)
        )
    }

    /// Groups an OmniWM action into a display category (Workspace / Focus / Window / Keybinds).
    private static func category(for action: String) -> String {
        let a = action.lowercased()
        if a.contains("workspace") || a.contains("space") { return "Workspace" }
        if a.contains("focus") { return "Focus" }
        if a.contains("window") || a.contains("move") || a.contains("resize") || a.contains("swap") { return "Window" }
        return "Keybinds"
    }
}
