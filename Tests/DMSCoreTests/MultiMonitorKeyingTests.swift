import Testing
import Foundation
@testable import DMSCore

@Suite("Multi-Monitor BarPanelKey Keying Tests")
struct MultiMonitorKeyingTests {

    @Test("Raw key format is displayID|position|configID with configID last")
    func rawKeyFormat() {
        let key = BarPanelKey(displayID: 69_811_234, configID: "main-bar", position: "top")
        #expect(key.rawKey == "69811234|top|main-bar")
    }

    @Test("Round-trip serialization preserves all fields")
    func roundTrip() {
        let key = BarPanelKey(displayID: 42, configID: "cfg", position: "bottom")
        let parsed = BarPanelKey(rawKey: key.rawKey)
        #expect(parsed == key)
        #expect(parsed?.displayID == 42)
        #expect(parsed?.configID == "cfg")
        #expect(parsed?.position == "bottom")
    }

    @Test("Config ids with underscores, hyphens, and spaces round-trip without collision")
    func specialCharacterConfigIDs() {
        let ids = ["my_bar", "bar-2", "bar with spaces", "a_b_c_d", "under_score-and.mixed 3", "prefix", "prefix_extra"]
        for id in ids {
            let key = BarPanelKey(displayID: 7, configID: id, position: "left")
            let parsed = BarPanelKey(rawKey: key.rawKey)
            #expect(parsed?.configID == id)
            #expect(parsed == key)
        }
        // A config id that is a prefix of another must never collide.
        let short = BarPanelKey(displayID: 7, configID: "prefix", position: "left")
        let long = BarPanelKey(displayID: 7, configID: "prefix_extra", position: "left")
        #expect(short != long)
        #expect(BarPanelKey(rawKey: short.rawKey)?.configID == "prefix")
        #expect(BarPanelKey(rawKey: long.rawKey)?.configID == "prefix_extra")
    }

    @Test("Config id containing the delimiter still parses because configID is last")
    func configIDContainingDelimiter() {
        let key = BarPanelKey(displayID: 9, configID: "a|b", position: "right")
        #expect(key.rawKey == "9|right|a|b")
        let parsed = BarPanelKey(rawKey: key.rawKey)
        #expect(parsed == key)
        #expect(parsed?.configID == "a|b")
        #expect(parsed?.position == "right")
        #expect(parsed?.displayID == 9)
    }

    @Test("Display id is preserved across monitor reorder and disconnect scenarios")
    func displayIDStabilityAcrossReorder() {
        // The same physical display keeps its CGDirectDisplayID no matter what array
        // index NSScreen.screens assigns to it after a reorder or hot-plug.
        let external = BarPanelKey(displayID: 69_811_234, configID: "main", position: "top")
        let builtin = BarPanelKey(displayID: 1, configID: "main", position: "top")
        #expect(external != builtin)
        #expect(external.displayID == 69_811_234)

        // Rebuilding the key from the same display id (e.g. after screens re-enumerate)
        // yields the identical raw key, so the panel survives the reorder.
        let rebuilt = BarPanelKey(displayID: external.displayID, configID: external.configID, position: external.position)
        #expect(rebuilt.rawKey == external.rawKey)
        #expect(Set([external, builtin, rebuilt]).count == 2)

        // Disconnecting the external display removes only its keys.
        var panels: [String: Int] = [external.rawKey: 1, builtin.rawKey: 2]
        let connectedIDs: Set<UInt32> = [1]
        panels = panels.filter { key, _ in
            guard let id = BarPanelKey(rawKey: key)?.displayID else { return false }
            return connectedIDs.contains(id)
        }
        #expect(panels.count == 1)
        #expect(panels[builtin.rawKey] == 2)
    }

    @Test("Keys are Hashable and work as dictionary keys")
    func hashableDictionaryUsage() {
        var panels: [String: Int] = [:]
        let a = BarPanelKey(displayID: 100, configID: "x", position: "top")
        let b = BarPanelKey(displayID: 200, configID: "x", position: "top")
        panels[a.rawKey] = 1
        panels[b.rawKey] = 2
        #expect(panels.count == 2)
        #expect(panels[a.rawKey] == 1)
        #expect(panels[b.rawKey] == 2)
        #expect(BarPanelKey(rawKey: a.rawKey)?.hashValue == a.hashValue)
    }

    @Test("Distinct positions and configs on the same display produce distinct keys")
    func distinctKeysPerDisplay() {
        let top = BarPanelKey(displayID: 5, configID: "cfg", position: "top")
        let bottom = BarPanelKey(displayID: 5, configID: "cfg", position: "bottom")
        let otherConfig = BarPanelKey(displayID: 5, configID: "cfg2", position: "top")
        #expect(top != bottom)
        #expect(top != otherConfig)
        #expect(top.rawKey != bottom.rawKey)
        #expect(BarPanelKey(rawKey: top.rawKey)?.position == "top")
        #expect(BarPanelKey(rawKey: bottom.rawKey)?.position == "bottom")
    }

    @Test("Legacy screenIndex_configID_position keys still parse safely")
    func legacyFormatFallback() {
        let legacy = BarPanelKey(rawKey: "0_my-bar_bottom")
        #expect(legacy != nil)
        #expect(legacy?.configID == "my-bar")
        #expect(legacy?.position == "bottom")
        #expect(legacy?.displayID == 0)

        // Legacy config ids containing underscores: delimited by first/last underscore.
        let legacyUnderscores = BarPanelKey(rawKey: "2_my_config_id_top")
        #expect(legacyUnderscores?.configID == "my_config_id")
        #expect(legacyUnderscores?.position == "top")
        #expect(legacyUnderscores?.displayID == 2)
    }

    @Test("Invalid keys are rejected")
    func invalidKeysRejected() {
        #expect(BarPanelKey(rawKey: "") == nil)
        #expect(BarPanelKey(rawKey: "abc") == nil)
        #expect(BarPanelKey(rawKey: "12") == nil)
        #expect(BarPanelKey(rawKey: "1|2") == nil)
        #expect(BarPanelKey(rawKey: "1|top") == nil)
        #expect(BarPanelKey(rawKey: "x|top|cfg") == nil)
        #expect(BarPanelKey(rawKey: "|top|cfg") == nil)
        #expect(BarPanelKey(rawKey: "1||cfg") == nil)
        #expect(BarPanelKey(rawKey: "1|top|") == nil)
        #expect(BarPanelKey(rawKey: "1_2") == nil)
        #expect(BarPanelKey(rawKey: "1_") == nil)
        #expect(BarPanelKey(rawKey: "_top") == nil)
    }
}
