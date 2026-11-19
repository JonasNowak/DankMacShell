import Testing
import Foundation
@testable import DMSCore

@Suite("Clipboard Sensitive-Content Filter Tests (v0.6 CLIP)")
struct ClipboardFilterTests {

    @Test("Blocked Pasteboard Types Reject the Change")
    func testBlockedTypes() {
        for blocked in ClipboardFilter.blockedPasteboardTypes {
            #expect(!ClipboardFilter.shouldRecord(
                pasteboardTypes: ["public.utf8-plain-text", blocked],
                sourceBundleID: "com.apple.Safari",
                sourceAppName: "Safari",
                filterEnabled: true
            ))
        }
    }

    @Test("Multi-Representation Items: One Concealed Type Poisons the Whole Change")
    func testMultiRepresentation() {
        // Plain string + PNG -> record
        #expect(ClipboardFilter.shouldRecord(
            pasteboardTypes: ["public.utf8-plain-text", "public.png"],
            sourceBundleID: "com.apple.TextEdit",
            sourceAppName: "TextEdit",
            filterEnabled: true
        ))
        // String + concealed -> reject entirely
        #expect(!ClipboardFilter.shouldRecord(
            pasteboardTypes: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"],
            sourceBundleID: "com.apple.TextEdit",
            sourceAppName: "TextEdit",
            filterEnabled: true
        ))
        // Concealed on a *different* item of the same change -> still reject
        #expect(!ClipboardFilter.shouldRecord(
            pasteboardTypes: ["public.png", "org.nspasteboard.TransientType"],
            sourceBundleID: nil,
            sourceAppName: nil,
            filterEnabled: true
        ))
    }

    @Test("Password Manager Detection by Bundle ID and Name")
    func testPasswordManagers() {
        #expect(ClipboardFilter.isPasswordManager(bundleID: "com.1password.1password", appName: nil))
        #expect(ClipboardFilter.isPasswordManager(bundleID: "com.bitwarden.desktop", appName: nil))
        #expect(ClipboardFilter.isPasswordManager(bundleID: "org.keepassxc.keepassxc", appName: nil))
        #expect(ClipboardFilter.isPasswordManager(bundleID: nil, appName: "1Password"))
        #expect(ClipboardFilter.isPasswordManager(bundleID: nil, appName: "Bitwarden"))
        #expect(ClipboardFilter.isPasswordManager(bundleID: nil, appName: "KeePassXC"))

        // Non-managers
        #expect(!ClipboardFilter.isPasswordManager(bundleID: "com.apple.Safari", appName: "Safari"))
        #expect(!ClipboardFilter.isPasswordManager(bundleID: "com.apple.Terminal", appName: "Terminal"))
        #expect(!ClipboardFilter.isPasswordManager(bundleID: nil, appName: nil))
    }

    @Test("Password Manager Origin Rejects Even Without Blocked Types")
    func testPasswordManagerOrigin() {
        #expect(!ClipboardFilter.shouldRecord(
            pasteboardTypes: ["public.utf8-plain-text"],
            sourceBundleID: "com.1password.1password",
            sourceAppName: "1Password",
            filterEnabled: true
        ))
        #expect(!ClipboardFilter.shouldRecord(
            pasteboardTypes: ["public.utf8-plain-text"],
            sourceBundleID: nil,
            sourceAppName: "KeePassXC",
            filterEnabled: true
        ))
    }

    @Test("Kill Switch Records Everything When Filter Disabled")
    func testFilterDisabled() {
        #expect(ClipboardFilter.shouldRecord(
            pasteboardTypes: ["org.nspasteboard.ConcealedType"],
            sourceBundleID: "com.bitwarden.desktop",
            sourceAppName: "Bitwarden",
            filterEnabled: false
        ))
    }

    @Test("Ordinary Copies Are Recorded")
    func testOrdinaryCopy() {
        #expect(ClipboardFilter.shouldRecord(
            pasteboardTypes: ["public.utf8-plain-text"],
            sourceBundleID: "com.apple.TextEdit",
            sourceAppName: "TextEdit",
            filterEnabled: true
        ))
        #expect(ClipboardFilter.shouldRecord(
            pasteboardTypes: ["public.utf8-plain-text", "public.rtf"],
            sourceBundleID: nil,
            sourceAppName: nil,
            filterEnabled: true
        ))
    }

    @Test("Apple Passwords and Keychain Access Are Blocked")
    func testAppleCredentialManagers() {
        #expect(ClipboardFilter.isPasswordManager(bundleID: "com.apple.passwords", appName: nil))
        #expect(ClipboardFilter.isPasswordManager(bundleID: "com.apple.keychainaccess", appName: nil))
        #expect(!ClipboardFilter.shouldRecord(
            pasteboardTypes: ["public.utf8-plain-text"],
            sourceBundleID: "com.apple.passwords",
            sourceAppName: "Passwords",
            filterEnabled: true
        ))
        #expect(!ClipboardFilter.shouldRecord(
            pasteboardTypes: ["public.utf8-plain-text"],
            sourceBundleID: "com.apple.keychainaccess",
            sourceAppName: "Keychain Access",
            filterEnabled: true
        ))
    }

    @Test("1Password 7 (com.agilebits.onepassword7) Is Blocked via the onepassword Fragment")
    func testOnePassword7() {
        #expect(ClipboardFilter.isPasswordManager(bundleID: "com.agilebits.onepassword7", appName: nil))
        #expect(ClipboardFilter.isPasswordManager(bundleID: nil, appName: "1Password 7"))
        #expect(!ClipboardFilter.shouldRecord(
            pasteboardTypes: ["public.utf8-plain-text"],
            sourceBundleID: "com.agilebits.onepassword7",
            sourceAppName: "1Password",
            filterEnabled: true
        ))
    }

    @Test("Proton Pass, Strongbox, MacPass, Dashlane, LastPass, Enpass, Keeper, NordPass, Secrets Are Blocked")
    func testAdditionalPasswordManagers() {
        let bundleIDs = [
            "ch.proton.pass",            // Proton Pass
            "com.strongbox.mac",         // Strongbox
            "org.macpass.MacPass",       // MacPass
            "com.dashlane.dashlane",     // Dashlane
            "com.lastpass.LastPass",     // LastPass
            "com.enpass.Enpass",         // Enpass
            "com.keeper.KeeperSecurity", // Keeper
            "com.nordpass.NordPass",     // NordPass
            "me.secrets.Secrets"         // Secrets
        ]
        for bid in bundleIDs {
            #expect(ClipboardFilter.isPasswordManager(bundleID: bid, appName: nil), "expected \(bid) to be blocked")
        }
        #expect(ClipboardFilter.isPasswordManager(bundleID: nil, appName: "Strongbox"))
        #expect(ClipboardFilter.isPasswordManager(bundleID: nil, appName: "Dashlane"))
        #expect(ClipboardFilter.isPasswordManager(bundleID: nil, appName: "NordPass"))
        #expect(!ClipboardFilter.shouldRecord(
            pasteboardTypes: ["public.utf8-plain-text"],
            sourceBundleID: "ch.proton.pass",
            sourceAppName: nil,
            filterEnabled: true
        ))
    }

    @Test("Password-Manager, Transient-Clipboard and Remote-Clipboard Pasteboard Types Are Blocked")
    func testNewBlockedPasteboardTypes() {
        let newTypes = [
            "com.agilebits.onepassword",
            "de.petermaurer.TransientPasteboardType",
            "com.typeit4me.clipping",
            "com.apple.is-remote-clipboard"
        ]
        for t in newTypes {
            #expect(ClipboardFilter.blockedPasteboardTypes.contains(t))
            #expect(!ClipboardFilter.shouldRecord(
                pasteboardTypes: ["public.utf8-plain-text", t],
                sourceBundleID: "com.apple.Safari",
                sourceAppName: "Safari",
                filterEnabled: true
            ))
        }
    }
}
