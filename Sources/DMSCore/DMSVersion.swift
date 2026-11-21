import Foundation

public enum DMSVersion: Sendable {
    public static let current = "0.9.1"

    public static var displayVersion: String {
        if let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !short.isEmpty {
            return short
        }
        return current
    }

    public static var userAgent: String {
        "DankMacShell/\(current) (https://github.com/JonasNowak/DankMacShell)"
    }

    /// Returns `true` when `candidate` is a newer version than `current`.
    ///
    /// Surrounding whitespace, a leading `v`/`V`, and build metadata (`+...`) are ignored.
    /// The core `major.minor.patch` is compared numerically (missing minor/patch pad with `0`);
    /// when the cores are equal, a final release outranks any pre-release tag
    /// (`1.0.0` > `1.0.0-beta.1`). Pre-release tags compare dot-separated identifiers
    /// numerically when both are integers, otherwise lexicographically; equal tags are not newer.
    public static func isNewerVersion(_ candidate: String, than current: String) -> Bool {
        func parse(_ raw: String) -> (core: (Int, Int, Int), preRelease: [String]) {
            var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if s.hasPrefix("v") || s.hasPrefix("V") {
                s.removeFirst()
            }
            if let plus = s.firstIndex(of: "+") {
                s = String(s[..<plus])
            }
            let halves = s.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            let coreNumbers = halves[0]
                .split(separator: ".", omittingEmptySubsequences: false)
                .map { Int($0) ?? 0 }
            let core = (
                coreNumbers.count > 0 ? coreNumbers[0] : 0,
                coreNumbers.count > 1 ? coreNumbers[1] : 0,
                coreNumbers.count > 2 ? coreNumbers[2] : 0
            )
            let preRelease: [String]
            if halves.count > 1 {
                preRelease = halves[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            } else {
                preRelease = []
            }
            return (core, preRelease)
        }

        let candidateParsed = parse(candidate)
        let currentParsed = parse(current)

        if candidateParsed.core != currentParsed.core {
            return candidateParsed.core > currentParsed.core
        }

        let candidatePre = candidateParsed.preRelease
        let currentPre = currentParsed.preRelease
        if candidatePre.isEmpty {
            // Final release: newer than any pre-release, equal to another final.
            return !currentPre.isEmpty
        }
        if currentPre.isEmpty {
            return false
        }

        for (index, candidateID) in candidatePre.enumerated() {
            if index >= currentPre.count { return true }
            let currentID = currentPre[index]
            if candidateID == currentID { continue }
            if let candidateNumber = Int(candidateID), let currentNumber = Int(currentID) {
                return candidateNumber > currentNumber
            }
            return candidateID > currentID
        }
        return candidatePre.count > currentPre.count
    }
}
