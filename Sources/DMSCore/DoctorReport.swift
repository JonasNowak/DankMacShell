import Foundation

/// Status of a single `dms doctor` check (v0.9.9).
public enum DoctorCheckStatus: String, Codable, Sendable, Equatable {
    case pass
    case warn
    case fail
    case info

    /// Terminal icon used by `DoctorReport.renderText`.
    public var icon: String {
        switch self {
        case .pass: return "✓"
        case .warn: return "!"
        case .fail: return "✗"
        case .info: return "·"
        }
    }

    /// ANSI SGR color code used by `DoctorReport.renderText(useColor: true)`.
    public var ansiColor: String {
        switch self {
        case .pass: return "32" // green
        case .warn: return "33" // yellow
        case .fail: return "31" // red
        case .info: return "36" // cyan
        }
    }
}

/// A single diagnostic check result produced by `dms doctor`.
public struct DoctorCheck: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var category: String
    public var title: String
    public var status: DoctorCheckStatus
    public var detail: String
    public var fixHint: String?

    public init(
        id: String,
        category: String,
        title: String,
        status: DoctorCheckStatus,
        detail: String,
        fixHint: String? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.status = status
        self.detail = detail
        self.fixHint = fixHint
    }

    private enum CodingKeys: String, CodingKey {
        case id, category, title, status, detail, fixHint
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        title = try container.decode(String.self, forKey: .title)
        status = try container.decode(DoctorCheckStatus.self, forKey: .status)
        detail = try container.decode(String.self, forKey: .detail)
        fixHint = try container.decodeIfPresent(String.self, forKey: .fixHint)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(category, forKey: .category)
        try container.encode(title, forKey: .title)
        try container.encode(status, forKey: .status)
        try container.encode(detail, forKey: .detail)
        try container.encodeIfPresent(fixHint, forKey: .fixHint)
    }
}

/// Aggregate diagnostics report produced by `dms doctor` (v0.9.9).
///
/// Pure value type: `Sendable` + `Codable`, renderable as a grouped terminal
/// report (`renderText`) or as pretty-printed ISO-8601 JSON (`renderJSON`).
public struct DoctorReport: Codable, Sendable, Equatable {
    public var version: String
    public var macOSVersion: String
    public var architecture: String
    public var generatedAt: Date
    public var checks: [DoctorCheck]

    public init(
        version: String,
        macOSVersion: String,
        architecture: String,
        generatedAt: Date = Date(),
        checks: [DoctorCheck]
    ) {
        self.version = version
        self.macOSVersion = macOSVersion
        self.architecture = architecture
        self.generatedAt = generatedAt
        self.checks = checks
    }

    public var passCount: Int { checks.filter { $0.status == .pass }.count }
    public var warnCount: Int { checks.filter { $0.status == .warn }.count }
    public var failCount: Int { checks.filter { $0.status == .fail }.count }
    public var infoCount: Int { checks.filter { $0.status == .info }.count }

    public var hasFailures: Bool { failCount > 0 }

    /// Exit code `dms doctor` should use: 1 when any check failed, 0 otherwise
    /// (warnings and info alone do not fail the run).
    public var recommendedExitCode: Int32 { failCount > 0 ? 1 : 0 }

    /// ISO-8601 formatter with fractional seconds so `renderJSON` round-trips
    /// `generatedAt` exactly through a matching decoder.
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Crisp grouped terminal report: category headers, one line per check with a
    /// status icon (✓ / ! / ✗ / ·), indented detail lines, indented `Fix: ...` hints,
    /// and a final summary line.
    public func renderText(useColor: Bool = true) -> String {
        func paint(_ code: String, _ text: String) -> String {
            useColor ? "\u{001B}[\(code)m\(text)\u{001B}[0m" : text
        }

        var lines: [String] = []
        lines.append(paint("1", "DankMacShell Doctor — v\(version)"))
        lines.append(paint("2", "macOS \(macOSVersion) · \(architecture) · generated \(Self.iso8601.string(from: generatedAt))"))
        lines.append("")

        // Group by category, preserving first-appearance order.
        var categoryOrder: [String] = []
        var byCategory: [String: [DoctorCheck]] = [:]
        for check in checks {
            if byCategory[check.category] == nil {
                categoryOrder.append(check.category)
            }
            byCategory[check.category, default: []].append(check)
        }

        for category in categoryOrder {
            lines.append(paint("1;4", category))
            for check in byCategory[category] ?? [] {
                lines.append("  \(paint(check.status.ansiColor, check.status.icon)) \(check.title)")
                if !check.detail.isEmpty {
                    lines.append("      \(check.detail)")
                }
                if let fixHint = check.fixHint {
                    lines.append(paint("33", "      Fix: \(fixHint)"))
                }
            }
            lines.append("")
        }

        let summary = "Summary: \(passCount) passed, \(warnCount) warning\(warnCount == 1 ? "" : "s"), \(failCount) failed, \(infoCount) info — exit code \(recommendedExitCode)"
        lines.append(paint(hasFailures ? "31" : "32", summary))
        return lines.joined(separator: "\n")
    }

    /// Pretty-printed, sorted-keys JSON with an ISO-8601 `generatedAt`.
    public func renderJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.iso8601.string(from: date))
        }
        let data = try encoder.encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                data,
                EncodingError.Context(codingPath: [], debugDescription: "DoctorReport JSON is not valid UTF-8")
            )
        }
        return json
    }
}
