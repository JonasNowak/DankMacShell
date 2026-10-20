import Foundation

/// Pill segment role indicating corner curvature in contiguous widget runs.
/// Ported verbatim from upstream DankMaterialShell (`quickshell/Modules/DBar/SegmentRoles.js`).
public enum SegmentRole: String, Sendable, Codable, Equatable, CaseIterable {
    case solo
    case first
    case middle
    case last
}

public enum BarSegmentRoleSolver: Sendable {

    public static func breaksRun(entry: BarWidgetEntry?, state: Bool?) -> Bool {
        if state == false { return true }
        guard let id = entry?.widgetId else { return false }
        return id == "spacer" || id == "separator"
    }

    /// Resolves the segment role for each widget entry.
    public static func resolve(entries: [BarWidgetEntry], participating: [Bool]) -> [SegmentRole] {
        let count = entries.count
        var roles: [SegmentRole] = Array(repeating: .solo, count: count)
        var run: [Int] = []

        let close = {
            if run.count > 1 {
                roles[run[0]] = .first
                roles[run[run.count - 1]] = .last
                for i in 1..<(run.count - 1) {
                    roles[run[i]] = .middle
                }
            }
            run.removeAll()
        }

        for i in 0..<count {
            let state = i < participating.count ? participating[i] : true
            if breaksRun(entry: entries[i], state: state) {
                close()
                continue
            }
            run.append(i)
        }
        close()

        return roles
    }
}
