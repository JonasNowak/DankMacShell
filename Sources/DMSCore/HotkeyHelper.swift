import Foundation
#if canImport(Carbon.HIToolbox)
import Carbon.HIToolbox
#endif

/// Carbon modifier masks preset enumeration with first-class Hyper Key (⌃⌥⇧⌘) support.
public enum HotkeyModifierPreset: String, CaseIterable, Identifiable, Sendable {
    case hyper = "hyper"
    case option = "option"
    case cmdOpt = "cmd+opt"
    case ctrlOpt = "ctrl+opt"
    case meh = "meh"
    case cmdCtrl = "cmd+ctrl"
    case cmdShift = "cmd+shift"
    case ctrlShift = "ctrl+shift"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hyper: return "Hyper Key (⌃⌥⇧⌘)"
        case .option: return "Option (⌥)"
        case .cmdOpt: return "Command + Option (⌘⌥)"
        case .ctrlOpt: return "Control + Option (⌃⌥)"
        case .meh: return "Meh Key (⌃⌥⇧)"
        case .cmdCtrl: return "Command + Control (⌘⌃)"
        case .cmdShift: return "Command + Shift (⌘⇧)"
        case .ctrlShift: return "Control + Shift (⌃⇧)"
        }
    }

    public var carbonModifiers: Int {
        switch self {
        case .hyper:
            return HotkeyHelper.hyperModifier
        case .option:
            return HotkeyHelper.optionModifier
        case .cmdOpt:
            return HotkeyHelper.cmdModifier | HotkeyHelper.optionModifier
        case .ctrlOpt:
            return HotkeyHelper.controlModifier | HotkeyHelper.optionModifier
        case .meh:
            return HotkeyHelper.mehModifier
        case .cmdCtrl:
            return HotkeyHelper.cmdModifier | HotkeyHelper.controlModifier
        case .cmdShift:
            return HotkeyHelper.cmdModifier | HotkeyHelper.shiftModifier
        case .ctrlShift:
            return HotkeyHelper.controlModifier | HotkeyHelper.shiftModifier
        }
    }
}

/// Helper for translating between key strings, modifier strings, Carbon HIToolbox masks and user-facing shortcut labels.
public struct HotkeyHelper: Sendable {
    // Carbon HIToolbox modifier constants
    public static let cmdModifier: Int = 256      // cmdKey
    public static let shiftModifier: Int = 512    // shiftKey
    public static let optionModifier: Int = 2048  // optionKey
    public static let controlModifier: Int = 4096 // controlKey

    /// Hyper Key: ⌃⌥⇧⌘ (Control + Option + Shift + Command) - 6912 in Carbon HIToolbox
    public static let hyperModifier: Int = controlModifier | optionModifier | shiftModifier | cmdModifier

    /// Meh Key: ⌃⌥⇧ (Control + Option + Shift) - 6656 in Carbon HIToolbox
    public static let mehModifier: Int = controlModifier | optionModifier | shiftModifier

    /// Parses a modifier string (e.g. "hyper", "option", "cmd+opt", "ctrl+opt+shift+cmd") into a Carbon modifier bitmask.
    public static func parseModifiers(_ str: String) -> Int {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            return hyperModifier
        }

        // Direct preset match
        if let preset = HotkeyModifierPreset(rawValue: trimmed) {
            return preset.carbonModifiers
        }

        var mask = 0
        let tokens = trimmed.components(separatedBy: CharacterSet(charactersIn: "+- ,_"))
        for token in tokens {
            let t = token.trimmingCharacters(in: .whitespaces)
            if t == "hyper" {
                mask |= hyperModifier
            } else if t == "meh" {
                mask |= mehModifier
            } else if t == "cmd" || t == "command" || t == "⌘" {
                mask |= cmdModifier
            } else if t == "opt" || t == "option" || t == "alt" || t == "⌥" {
                mask |= optionModifier
            } else if t == "ctrl" || t == "control" || t == "⌃" {
                mask |= controlModifier
            } else if t == "shift" || t == "⇧" {
                mask |= shiftModifier
            }
        }

        return mask == 0 ? hyperModifier : mask
    }

    /// Parses a key name string (e.g. "w", "space", "return", "tab", "p") into a Carbon virtual key code.
    public static func parseKeyCode(_ str: String) -> Int {
        let key = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "a": return 0
        case "b": return 11
        case "c": return 8
        case "d": return 2
        case "e": return 14
        case "f": return 3
        case "g": return 5
        case "h": return 4
        case "i": return 34
        case "j": return 38
        case "k": return 40
        case "l": return 37
        case "m": return 46
        case "n": return 45
        case "o": return 31
        case "p": return 35
        case "q": return 12
        case "r": return 15
        case "s": return 1
        case "t": return 17
        case "u": return 32
        case "v": return 9
        case "w": return 13
        case "x": return 7
        case "y": return 16
        case "z": return 6

        case "0": return 29
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "5": return 23
        case "6": return 22
        case "7": return 26
        case "8": return 28
        case "9": return 25

        case "space": return 49
        case "return", "enter": return 36
        case "tab": return 48
        case "escape", "esc": return 53
        case "backslash", "\\": return 42
        case "slash", "/": return 44
        case "grave", "backtick", "`": return 50
        case "left", "leftarrow": return 123
        case "right", "rightarrow": return 124
        case "down", "downarrow": return 125
        case "up", "uparrow": return 126

        default:
            return 13 // Default to 'W' for wallpaper
        }
    }

    /// Parses both key and modifier strings into Carbon keycode and modifier bitmask.
    public static func parse(key: String, modifiers: String) -> (keyCode: Int, modifiers: Int) {
        return (parseKeyCode(key), parseModifiers(modifiers))
    }

    /// Formats a user-friendly display string for a hotkey combination.
    public static func displayString(key: String, modifiers: String) -> String {
        let mask = parseModifiers(modifiers)
        var parts: [String] = []

        if mask == hyperModifier {
            let keyText = keyDisplay(key)
            return "✧ Hyper + \(keyText) (⌃⌥⇧⌘\(keyText))"
        }

        if mask == mehModifier {
            let keyText = keyDisplay(key)
            return "Meh + \(keyText) (⌃⌥⇧\(keyText))"
        }

        if (mask & controlModifier) != 0 { parts.append("⌃") }
        if (mask & optionModifier) != 0 { parts.append("⌥") }
        if (mask & shiftModifier) != 0 { parts.append("⇧") }
        if (mask & cmdModifier) != 0 { parts.append("⌘") }

        let modString = parts.joined()
        let keyText = keyDisplay(key)
        return modString.isEmpty ? keyText : "\(modString) \(keyText)"
    }

    private static func keyDisplay(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
        case "space": return "Space"
        case "return", "enter": return "↵"
        case "tab": return "⇥"
        case "escape", "esc": return "Esc"
        case "backslash": return "\\"
        case "slash": return "/"
        case "grave": return "`"
        case "left": return "←"
        case "right": return "→"
        case "up": return "↑"
        case "down": return "↓"
        default: return trimmed.uppercased()
        }
    }

    /// Predefined list of commonly used trigger key options for UI pickers.
    public static let standardKeyOptions: [HotkeyKeyOption] = [
        HotkeyKeyOption(title: "Space", tag: "space"),
        HotkeyKeyOption(title: "Return / Enter (↵)", tag: "return"),
        HotkeyKeyOption(title: "Tab (⇥)", tag: "tab"),
        HotkeyKeyOption(title: "Escape (Esc)", tag: "escape"),
        HotkeyKeyOption(title: "W", tag: "w"),
        HotkeyKeyOption(title: "D", tag: "d"),
        HotkeyKeyOption(title: "N", tag: "n"),
        HotkeyKeyOption(title: "V", tag: "v"),
        HotkeyKeyOption(title: "P", tag: "p"),
        HotkeyKeyOption(title: "C", tag: "c"),
        HotkeyKeyOption(title: "A", tag: "a"),
        HotkeyKeyOption(title: "B", tag: "b"),
        HotkeyKeyOption(title: "E", tag: "e"),
        HotkeyKeyOption(title: "F", tag: "f"),
        HotkeyKeyOption(title: "G", tag: "g"),
        HotkeyKeyOption(title: "H", tag: "h"),
        HotkeyKeyOption(title: "I", tag: "i"),
        HotkeyKeyOption(title: "J", tag: "j"),
        HotkeyKeyOption(title: "K", tag: "k"),
        HotkeyKeyOption(title: "L", tag: "l"),
        HotkeyKeyOption(title: "M", tag: "m"),
        HotkeyKeyOption(title: "O", tag: "o"),
        HotkeyKeyOption(title: "Q", tag: "q"),
        HotkeyKeyOption(title: "R", tag: "r"),
        HotkeyKeyOption(title: "S", tag: "s"),
        HotkeyKeyOption(title: "T", tag: "t"),
        HotkeyKeyOption(title: "U", tag: "u"),
        HotkeyKeyOption(title: "X", tag: "x"),
        HotkeyKeyOption(title: "Y", tag: "y"),
        HotkeyKeyOption(title: "Z", tag: "z"),
        HotkeyKeyOption(title: "0", tag: "0"),
        HotkeyKeyOption(title: "1", tag: "1"),
        HotkeyKeyOption(title: "2", tag: "2"),
        HotkeyKeyOption(title: "3", tag: "3"),
        HotkeyKeyOption(title: "4", tag: "4"),
        HotkeyKeyOption(title: "5", tag: "5"),
        HotkeyKeyOption(title: "6", tag: "6"),
        HotkeyKeyOption(title: "7", tag: "7"),
        HotkeyKeyOption(title: "8", tag: "8"),
        HotkeyKeyOption(title: "9", tag: "9"),
        HotkeyKeyOption(title: "\\ (Backslash)", tag: "backslash"),
        HotkeyKeyOption(title: "/ (Slash)", tag: "slash"),
        HotkeyKeyOption(title: "` (Grave / Backtick)", tag: "grave"),
        HotkeyKeyOption(title: "← Left Arrow", tag: "left"),
        HotkeyKeyOption(title: "→ Right Arrow", tag: "right"),
        HotkeyKeyOption(title: "↑ Up Arrow", tag: "up"),
        HotkeyKeyOption(title: "↓ Down Arrow", tag: "down")
    ]
}

/// Represents an item in a key selection picker.
public struct HotkeyKeyOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let tag: String

    public init(title: String, tag: String) {
        self.id = tag
        self.title = title
        self.tag = tag
    }
}
