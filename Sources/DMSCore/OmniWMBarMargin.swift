import Foundation

/// Valid screen edges for DankBar placement when syncing outer gaps with OmniWM.
public enum OmniWMBarEdge: String, CaseIterable, Sendable {
    case top
    case bottom
    case left
    case right

    public init?(position: String) {
        self.init(rawValue: position.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    /// Opposite screen edge on the same axis, holding the normal (non-bar) outer gap.
    public var opposite: OmniWMBarEdge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .right
        case .right: return .left
        }
    }
}

/// Surgical, comment-preserving updater for `[gaps.outer]` in OmniWM's `settings.toml`.
public struct OmniWMMarginUpdater: Sendable {
    /// Default screen edge margin (in px) reserved for DankBar in OmniWM `[gaps.outer]`.
    public static let defaultBarReservedMargin: Double = 60.0

    /// Updates `[gaps.outer]` in `tomlContent` when moving DankBar from `oldPosition` to `newPosition`.
    ///
    /// - Restores `oldPosition` to the value currently held by its opposite edge before writing
    ///   (e.g., `top -> bottom` copies `bottom` to `top`, `left -> top` copies `right` to `left`,
    ///   and `top -> left` copies `bottom` to `top`).
    /// - Sets `newPosition` to `barMargin` (`60.0` by default).
    /// - Preserves all unrelated sections, keys, comments, hotkeys, and formatting.
    /// - Returns `tomlContent` unchanged when either edge is invalid or both edges match.
    public static func updateOuterGaps(
        in tomlContent: String,
        from oldPosition: String,
        to newPosition: String,
        barMargin: Double = defaultBarReservedMargin
    ) -> String {
        guard let oldEdge = OmniWMBarEdge(position: oldPosition),
              let newEdge = OmniWMBarEdge(position: newPosition),
              oldEdge != newEdge else {
            return tomlContent
        }

        let lineEnding = tomlContent.contains("\r\n") ? "\r\n" : "\n"
        let lines = tomlContent
            .components(separatedBy: "\n")
            .map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }

        // Read existing `[gaps.outer]` values first so opposite-edge lookups remain order-independent.
        let existingOuterGaps = parseOuterGaps(in: lines)
        let restoredValue = existingOuterGaps[oldEdge.opposite] ?? "0.0"
        let reservedValue = formatTOMLMargin(barMargin)

        let updates: [String: String] = [
            oldEdge.rawValue: restoredValue,
            newEdge.rawValue: reservedValue
        ]

        return applyOuterGapUpdates(lines: lines, updates: updates, lineEnding: lineEnding)
    }

    private enum SectionHeader {
        case table(String)
        case arrayTable
    }

    private static func parseOuterGaps(in lines: [String]) -> [OmniWMBarEdge: String] {
        var result: [OmniWMBarEdge: String] = [:]
        var currentSection: String?

        for line in lines {
            if let header = parseSectionHeader(line) {
                switch header {
                case .table(let name): currentSection = name
                case .arrayTable: currentSection = nil
                }
                continue
            }

            guard currentSection == "gaps.outer",
                  let kv = parseKeyValue(line),
                  let edge = OmniWMBarEdge(rawValue: kv.key),
                  isValidTOMLNumber(kv.value) else {
                continue
            }

            result[edge] = kv.value
        }

        return result
    }

    private static func applyOuterGapUpdates(
        lines: [String],
        updates: [String: String],
        lineEnding: String
    ) -> String {
        var output: [String] = []
        output.reserveCapacity(lines.count + 4)

        var inGapsOuter = false
        var handledGapsOuter = false
        var seenKeys = Set<String>()

        func flushMissingKeys() {
            guard inGapsOuter else { return }
            let missingKeys = updates.keys.filter { !seenKeys.contains($0) }.sorted()
            if !missingKeys.isEmpty {
                // Keep trailing blank lines below inserted keys so section spacing stays intact.
                var trailingBlanks: [String] = []
                while let last = output.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
                    trailingBlanks.append(output.removeLast())
                }
                for key in missingKeys {
                    if let val = updates[key] {
                        output.append("\(key) = \(val)")
                    }
                }
                output.append(contentsOf: trailingBlanks.reversed())
            }
            inGapsOuter = false
        }

        for line in lines {
            if let header = parseSectionHeader(line) {
                flushMissingKeys()
                switch header {
                case .table(let name):
                    if name == "gaps.outer" && !handledGapsOuter {
                        inGapsOuter = true
                        handledGapsOuter = true
                        seenKeys.removeAll()
                    } else {
                        inGapsOuter = false
                    }
                case .arrayTable:
                    inGapsOuter = false
                }
                output.append(line)
                continue
            }

            if inGapsOuter,
               let kv = parseKeyValue(line),
               let newValue = updates[kv.key] {
                output.append("\(kv.leadingWhitespace)\(kv.key) = \(newValue)")
                seenKeys.insert(kv.key)
                continue
            }

            output.append(line)
        }

        flushMissingKeys()

        if !handledGapsOuter {
            let hadTrailingNewline = lines.count > 1 && lines.last?.isEmpty == true
            while let last = output.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
                output.removeLast()
            }
            if !output.isEmpty {
                output.append("")
            }
            output.append("[gaps.outer]")
            for key in updates.keys.sorted() {
                if let val = updates[key] {
                    output.append("\(key) = \(val)")
                }
            }
            if hadTrailingNewline {
                output.append("")
            }
        }

        return output.joined(separator: lineEnding)
    }

    private static func parseSectionHeader(_ line: String) -> SectionHeader? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[") else { return nil }
        if trimmed.hasPrefix("[[") {
            return .arrayTable
        }
        guard let closeIdx = trimmed.firstIndex(of: "]") else { return nil }
        let afterClose = trimmed[trimmed.index(after: closeIdx)...].trimmingCharacters(in: .whitespaces)
        guard afterClose.isEmpty || afterClose.hasPrefix("#") else { return nil }
        let nameStart = trimmed.index(after: trimmed.startIndex)
        let name = trimmed[nameStart..<closeIdx].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        return .table(name)
    }

    private static func parseKeyValue(_ line: String) -> (leadingWhitespace: String, key: String, value: String)? {
        let leadingWhitespace = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
              let eqIdx = trimmed.firstIndex(of: "=") else {
            return nil
        }

        let key = trimmed[..<eqIdx].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }

        let rhsFull = trimmed[trimmed.index(after: eqIdx)...]
        let rhsWithoutComment = rhsFull.firstIndex(of: "#").map { rhsFull[..<$0] } ?? rhsFull
        let value = rhsWithoutComment.trimmingCharacters(in: .whitespaces)
        return (leadingWhitespace, key, value)
    }

    private static func isValidTOMLNumber(_ raw: String) -> Bool {
        let normalized = raw.replacingOccurrences(of: "_", with: "")
        guard let num = Double(normalized) else { return false }
        return num.isFinite
    }

    private static func formatTOMLMargin(_ value: Double) -> String {
        let clamped = max(0.0, value.isFinite ? value : defaultBarReservedMargin)
        let normalized = clamped == 0 ? 0.0 : clamped
        if normalized.rounded() == normalized {
            return String(format: "%.1f", normalized)
        }
        return String(normalized)
    }
}
