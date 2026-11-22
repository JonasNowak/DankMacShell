import Testing
import Foundation
@testable import DMSCore

@Suite("Keybind Conflict Detector Tests (Phase 7 Shard 4)")
struct KeybindConflictDetectorTests {

    @Test("Identical modifiers in different order are detected as a conflict")
    func detectsIdenticalModifiersInDifferentOrder() {
        let a = DMSHotkeyBinding(id: "a", title: "Launcher", key: "D", modifiers: ["cmd", "option"])
        let b = DMSHotkeyBinding(id: "b", title: "Dash", key: "d", modifiers: ["option", "cmd"])
        let conflicts = KeybindConflictDetector.findConflicts(in: [a, b])
        #expect(conflicts.count == 1)
        #expect(conflicts[0].signature == "cmd+option|d")
        #expect(conflicts[0].bindingIDs == ["a", "b"])
        #expect(conflicts[0].displayKeys.contains("⌘"))
        #expect(conflicts[0].displayKeys.contains("D"))
    }

    @Test("Disabled bindings are ignored")
    func ignoresDisabledBindings() {
        let a = DMSHotkeyBinding(id: "a", title: "A", key: "d", modifiers: ["option"], isEnabled: false)
        let b = DMSHotkeyBinding(id: "b", title: "B", key: "d", modifiers: ["option"])
        #expect(KeybindConflictDetector.findConflicts(in: [a, b]).isEmpty)

        let c = DMSHotkeyBinding(id: "c", title: "C", key: "d", modifiers: ["option"], isEnabled: false)
        #expect(KeybindConflictDetector.findConflicts(in: [a, c]).isEmpty)
    }

    @Test("Empty keys are ignored")
    func ignoresEmptyKeys() {
        let a = DMSHotkeyBinding(id: "a", title: "A", key: "", modifiers: ["option"])
        let b = DMSHotkeyBinding(id: "b", title: "B", key: "   ", modifiers: ["option"])
        #expect(KeybindConflictDetector.findConflicts(in: [a, b]).isEmpty)
    }

    @Test("Unique bindings return no conflicts")
    func returnsEmptyWhenUnique() {
        let bindings = [
            DMSHotkeyBinding(id: "launcher", title: "Launcher", key: "space", modifiers: ["option"]),
            DMSHotkeyBinding(id: "dash", title: "Dash", key: "d", modifiers: ["option"]),
            DMSHotkeyBinding(id: "notepad", title: "Notepad", key: "n", modifiers: ["option"]),
            DMSHotkeyBinding(id: "clipboard", title: "Clipboard", key: "v", modifiers: ["option"]),
            DMSHotkeyBinding(id: "picker", title: "Picker", key: "w", modifiers: ["option"])
        ]
        #expect(KeybindConflictDetector.findConflicts(in: bindings).isEmpty)
    }

    @Test("Same key with different modifiers is not a conflict")
    func differentModifiersNoConflict() {
        let a = DMSHotkeyBinding(id: "a", title: "A", key: "d", modifiers: ["option"])
        let b = DMSHotkeyBinding(id: "b", title: "B", key: "d", modifiers: ["cmd", "option"])
        #expect(KeybindConflictDetector.findConflicts(in: [a, b]).isEmpty)
    }

    @Test("Three-way conflict groups all binding ids")
    func threeWayConflict() {
        let a = DMSHotkeyBinding(id: "c", title: "C", key: "x", modifiers: ["shift", "ctrl"])
        let b = DMSHotkeyBinding(id: "a", title: "A", key: "X", modifiers: ["ctrl", "shift"])
        let c = DMSHotkeyBinding(id: "b", title: "B", key: "x", modifiers: ["shift", "ctrl"])
        let conflicts = KeybindConflictDetector.findConflicts(in: [a, b, c])
        #expect(conflicts.count == 1)
        #expect(conflicts[0].bindingIDs == ["a", "b", "c"])
        #expect(conflicts[0].signature == "ctrl+shift|x")
    }

    @Test("Multiple distinct conflicts are all reported, sorted by signature")
    func multipleConflicts() {
        let bindings = [
            DMSHotkeyBinding(id: "1", title: "One", key: "d", modifiers: ["option"]),
            DMSHotkeyBinding(id: "2", title: "Two", key: "d", modifiers: ["option"]),
            DMSHotkeyBinding(id: "3", title: "Three", key: "n", modifiers: ["cmd"]),
            DMSHotkeyBinding(id: "4", title: "Four", key: "n", modifiers: ["cmd"])
        ]
        let conflicts = KeybindConflictDetector.findConflicts(in: bindings)
        #expect(conflicts.count == 2)
        #expect(conflicts[0].signature < conflicts[1].signature)
        // "cmd|n" sorts before "option|d"
        #expect(conflicts[0].signature == "cmd|n")
        #expect(conflicts[0].bindingIDs == ["3", "4"])
        #expect(conflicts[1].signature == "option|d")
        #expect(conflicts[1].bindingIDs == ["1", "2"])
    }
}

@Suite("OmniWM Keybind Parser Tests (Phase 7 Shard 4)")
struct OmniWMKeybindParserTests {

    @Test("Parses key = value bindings in a [keybinds] section")
    func parsesKeyValueBindings() {
        let toml = """
        [keybinds]
        focus-left = "alt+h"
        focus-right = "alt+l"
        """
        let entries = OmniWMKeybindParser.parse(toml: toml)
        #expect(entries.count == 2)
        #expect(entries[0].action == "focus-left")
        #expect(entries[0].keys == "⌥ H")
        #expect(entries[0].category == "Focus")
        #expect(entries[1].action == "focus-right")
        #expect(entries[1].keys == "⌥ L")
    }

    @Test("Parses [[keybinds]] array-of-tables with key + action pairs")
    func parsesArrayOfTables() {
        let toml = """
        [[keybinds]]
        key = "cmd+shift+1"
        action = "move-to-workspace-1"

        [[keybinds]]
        action = "focus-right"
        key = "ctrl+alt+right"
        """
        let entries = OmniWMKeybindParser.parse(toml: toml)
        #expect(entries.count == 2)
        #expect(entries[0].action == "move-to-workspace-1")
        #expect(entries[0].keys == "⇧⌘ 1")
        #expect(entries[0].category == "Workspace")
        #expect(entries[1].action == "focus-right")
        #expect(entries[1].keys == "⌃⌥ →")
        #expect(entries[1].category == "Focus")
    }

    @Test("Parses [bindings] sections")
    func parsesBindingsSection() {
        let toml = """
        [bindings]
        close-window = "alt+F4"
        """
        let entries = OmniWMKeybindParser.parse(toml: toml)
        #expect(entries.count == 1)
        #expect(entries[0].action == "close-window")
        #expect(entries[0].keys == "⌥ F4")
        #expect(entries[0].category == "Window")
    }

    @Test("Comments and blank lines are skipped")
    func skipsCommentsAndBlankLines() {
        let toml = """

        # OmniWM settings
        [keybinds]
        # focus the window to the left
        focus-left = "alt+h" # trailing comment

        [gaps]
        inner = 8
        """
        let entries = OmniWMKeybindParser.parse(toml: toml)
        #expect(entries.count == 1)
        #expect(entries[0].action == "focus-left")
        #expect(entries[0].keys == "⌥ H")
    }

    @Test("Non-keybind sections are ignored")
    func ignoresNonKeybindSections() {
        let toml = """
        [general]
        focus-left = "alt+h"

        [gaps]
        inner = 8
        outer = 12
        """
        #expect(OmniWMKeybindParser.parse(toml: toml).isEmpty)
    }

    @Test("Modifier symbols are formatted cleanly")
    func formatsModifierSymbols() {
        let toml = """
        [keybinds]
        a = "alt+x"
        b = "cmd+shift+p"
        c = "ctrl+alt+delete"
        d = "super+space"
        e = "shift+left"
        f = "control+option+cmd+shift+q"
        """
        let entries = OmniWMKeybindParser.parse(toml: toml)
        #expect(entries.count == 6)
        #expect(entries[0].keys == "⌥ X")
        #expect(entries[1].keys == "⇧⌘ P")
        #expect(entries[2].keys == "⌃⌥ ⌫")
        #expect(entries[3].keys == "⌘ Space")
        #expect(entries[4].keys == "⇧ ←")
        #expect(entries[5].keys == "⌃⌥⇧⌘ Q")
    }

    @Test("Array-valued keys join multiple combos")
    func parsesArrayKeys() {
        let toml = """
        [[keybinds]]
        keys = ["alt+h", "alt+left"]
        action = "focus-left"
        """
        let entries = OmniWMKeybindParser.parse(toml: toml)
        #expect(entries.count == 1)
        #expect(entries[0].keys == "⌥ H / ⌥ ←")
    }

    @Test("Entries get stable unique ids")
    func stableUniqueIds() {
        let toml = """
        [keybinds]
        focus-left = "alt+h"
        focus-right = "alt+l"
        """
        let entries = OmniWMKeybindParser.parse(toml: toml)
        #expect(entries.allSatisfy { !$0.id.isEmpty })
        #expect(Set(entries.map { $0.id }).count == entries.count)
    }

    @Test("Empty input yields no entries")
    func emptyInput() {
        #expect(OmniWMKeybindParser.parse(toml: "").isEmpty)
        #expect(OmniWMKeybindParser.parse(toml: "# only a comment\n\n").isEmpty)
    }
}
