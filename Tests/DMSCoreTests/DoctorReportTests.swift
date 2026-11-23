import Testing
import Foundation
@testable import DMSCore

@Suite("DoctorReport Tests")
struct DoctorReportTests {

    private func sampleChecks() -> [DoctorCheck] {
        [
            DoctorCheck(id: "runtime.daemon", category: "Runtime & IPC", title: "Daemon running", status: .pass, detail: "pid 42"),
            DoctorCheck(id: "runtime.socket", category: "Runtime & IPC", title: "Socket round-trip", status: .warn, detail: "812 ms", fixHint: "Restart with 'dms restart'."),
            DoctorCheck(id: "bundle.exists", category: "App Bundle & Signing", title: "App bundle", status: .fail, detail: "not found in ~/Applications", fixHint: "Run ./build.sh."),
            DoctorCheck(id: "tools.gh", category: "Companion Tools", title: "GitHub CLI", status: .info, detail: "not found on PATH"),
        ]
    }

    private func sampleReport() -> DoctorReport {
        DoctorReport(
            version: "0.9.9",
            macOSVersion: "macOS 26.1",
            architecture: "arm64",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            checks: sampleChecks()
        )
    }

    // MARK: - Counts

    @Test("counts per status")
    func testCounts() {
        let report = sampleReport()
        #expect(report.passCount == 1)
        #expect(report.warnCount == 1)
        #expect(report.failCount == 1)
        #expect(report.infoCount == 1)
        #expect(report.passCount + report.warnCount + report.failCount + report.infoCount == report.checks.count)
    }

    @Test("empty report has zero counts")
    func testEmptyReportCounts() {
        let report = DoctorReport(version: "0.9.9", macOSVersion: "macOS 26.1", architecture: "arm64", checks: [])
        #expect(report.passCount == 0)
        #expect(report.warnCount == 0)
        #expect(report.failCount == 0)
        #expect(report.infoCount == 0)
    }

    // MARK: - hasFailures / recommendedExitCode

    @Test("hasFailures and recommendedExitCode with a failure")
    func testExitCodeWithFailure() {
        let report = sampleReport()
        #expect(report.hasFailures)
        #expect(report.recommendedExitCode == 1)
    }

    @Test("warnings-only report exits 0")
    func testExitCodeWarningsOnly() {
        var report = sampleReport()
        report.checks.removeAll { $0.status == .fail }
        #expect(!report.hasFailures)
        #expect(report.warnCount == 1)
        #expect(report.recommendedExitCode == 0)
    }

    @Test("all-pass report exits 0")
    func testExitCodeAllPass() {
        let report = DoctorReport(
            version: "0.9.9",
            macOSVersion: "macOS 26.1",
            architecture: "arm64",
            checks: [DoctorCheck(id: "a", category: "c", title: "t", status: .pass, detail: "d")]
        )
        #expect(!report.hasFailures)
        #expect(report.recommendedExitCode == 0)
    }

    // MARK: - DoctorCheckStatus metadata

    @Test("status raw values and icons")
    func testStatusMetadata() {
        #expect(DoctorCheckStatus.pass.rawValue == "pass")
        #expect(DoctorCheckStatus.warn.rawValue == "warn")
        #expect(DoctorCheckStatus.fail.rawValue == "fail")
        #expect(DoctorCheckStatus.info.rawValue == "info")
        #expect(DoctorCheckStatus.pass.icon == "✓")
        #expect(DoctorCheckStatus.warn.icon == "!")
        #expect(DoctorCheckStatus.fail.icon == "✗")
        #expect(DoctorCheckStatus.info.icon == "·")
    }

    // MARK: - Codable

    @Test("DoctorCheck Codable omits nil fixHint and round-trips")
    func testCheckCodableRoundTrip() throws {
        let check = DoctorCheck(id: "x", category: "c", title: "t", status: .info, detail: "d")
        let data = try JSONEncoder().encode(check)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(!json.contains("fixHint"))
        let decoded = try JSONDecoder().decode(DoctorCheck.self, from: data)
        #expect(decoded == check)

        let withHint = DoctorCheck(id: "y", category: "c", title: "t", status: .fail, detail: "d", fixHint: "do the thing")
        let data2 = try JSONEncoder().encode(withHint)
        let decoded2 = try JSONDecoder().decode(DoctorCheck.self, from: data2)
        #expect(decoded2 == withHint)
        #expect(decoded2.fixHint == "do the thing")
    }

    @Test("renderJSON produces pretty sorted-keys ISO-8601 JSON that round-trips")
    func testRenderJSONRoundTrip() throws {
        let report = sampleReport()
        let json = try report.renderJSON()

        // Pretty-printed (multi-line) and ISO-8601 timestamp for 1_700_000_000 = 2023-11-14T22:13:20Z.
        #expect(json.contains("\n"))
        #expect(json.contains("2023-11-14T22:13:20"))
        #expect(json.contains("\"architecture\""))
        #expect(json.contains("\"arm64\""))
        #expect(json.contains("\"status\" : \"warn\""))
        // nil fixHint is omitted, not encoded as null.
        #expect(!json.contains("null"))
        // sortedKeys: top-level keys in alphabetical order.
        let keys = ["\"architecture\"", "\"checks\"", "\"generatedAt\"", "\"macOSVersion\"", "\"version\""]
        var lastIndex = -1
        for key in keys {
            let range = json.range(of: key)
            #expect(range != nil)
            #expect(range!.lowerBound > json.startIndex && json.distance(from: json.startIndex, to: range!.lowerBound) > lastIndex)
            lastIndex = json.distance(from: json.startIndex, to: range!.lowerBound)
        }

        // Round-trip through a decoder with a matching ISO-8601 strategy.
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { container in
            let single = try container.singleValueContainer()
            let string = try single.decode(String.self)
            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(in: single, debugDescription: "invalid ISO-8601 date: \(string)")
            }
            return date
        }
        let decoded = try decoder.decode(DoctorReport.self, from: data)
        #expect(decoded == report)
        #expect(decoded.checks.count == 4)
        #expect(decoded.checks[1].fixHint == "Restart with 'dms restart'.")
    }

    // MARK: - renderText

    @Test("renderText(useColor: false) has icons, category headers, details, Fix hints, summary — and no ANSI codes")
    func testRenderTextPlain() {
        let report = sampleReport()
        let text = report.renderText(useColor: false)

        #expect(!text.contains("\u{001B}"))
        #expect(text.contains("DankMacShell Doctor — v0.9.9"))
        #expect(text.contains("arm64"))
        // Icons per status.
        #expect(text.contains("✓ Daemon running"))
        #expect(text.contains("! Socket round-trip"))
        #expect(text.contains("✗ App bundle"))
        #expect(text.contains("· GitHub CLI"))
        // Category headers.
        #expect(text.contains("Runtime & IPC"))
        #expect(text.contains("App Bundle & Signing"))
        #expect(text.contains("Companion Tools"))
        // Detail lines.
        #expect(text.contains("pid 42"))
        #expect(text.contains("812 ms"))
        // Indented Fix hints.
        #expect(text.contains("      Fix: Restart with 'dms restart'."))
        #expect(text.contains("      Fix: Run ./build.sh."))
        // The info check has no fix hint.
        #expect(!text.contains("Fix: ") || text.components(separatedBy: "Fix: ").count - 1 == 2)
        // Final summary line.
        #expect(text.contains("Summary: 1 passed, 1 warning, 1 failed, 1 info — exit code 1"))
    }

    @Test("renderText groups checks under their category header in first-seen order")
    func testRenderTextCategoryGrouping() {
        let text = sampleReport().renderText(useColor: false)
        func index(of needle: String) -> String.Index {
            guard let range = text.range(of: needle) else {
                Issue.record("missing '\(needle)' in:\n\(text)")
                return text.endIndex
            }
            return range.lowerBound
        }
        let runtimeHeader = index(of: "Runtime & IPC")
        let daemon = index(of: "Daemon running")
        let socket = index(of: "Socket round-trip")
        let bundleHeader = index(of: "App Bundle & Signing")
        let bundle = index(of: "App bundle")
        let toolsHeader = index(of: "Companion Tools")
        let gh = index(of: "GitHub CLI")
        let summary = index(of: "Summary:")

        #expect(runtimeHeader < daemon && daemon < socket && socket < bundleHeader)
        #expect(bundleHeader < bundle && bundle < toolsHeader)
        #expect(toolsHeader < gh && gh < summary)
    }

    @Test("renderText(useColor: true) wraps icons and summary in ANSI codes")
    func testRenderTextColor() {
        let text = sampleReport().renderText(useColor: true)
        #expect(text.contains("\u{001B}[32m✓\u{001B}[0m")) // pass green
        #expect(text.contains("\u{001B}[33m!\u{001B}[0m")) // warn yellow
        #expect(text.contains("\u{001B}[31m✗\u{001B}[0m")) // fail red
        #expect(text.contains("\u{001B}[36m·\u{001B}[0m")) // info cyan
        #expect(text.contains("\u{001B}[31mSummary:"))    // failing summary in red
        #expect(text.contains("\u{001B}[33m      Fix:"))   // fix hints in yellow
    }

    @Test("renderText summary pluralizes warnings and exits 0 without failures")
    func testRenderTextSummaryPluralization() {
        let report = DoctorReport(
            version: "0.9.9",
            macOSVersion: "macOS 26.1",
            architecture: "arm64",
            generatedAt: Date(timeIntervalSince1970: 0),
            checks: [
                DoctorCheck(id: "a", category: "C", title: "one", status: .warn, detail: "d"),
                DoctorCheck(id: "b", category: "C", title: "two", status: .warn, detail: "d"),
                DoctorCheck(id: "c", category: "C", title: "three", status: .pass, detail: "d"),
            ]
        )
        let text = report.renderText(useColor: false)
        #expect(text.contains("Summary: 1 passed, 2 warnings, 0 failed, 0 info — exit code 0"))
    }

    @Test("empty report renders header and zero summary")
    func testRenderTextEmptyReport() {
        let report = DoctorReport(version: "0.9.9", macOSVersion: "macOS 26.1", architecture: "arm64", generatedAt: Date(timeIntervalSince1970: 0), checks: [])
        let text = report.renderText(useColor: false)
        #expect(text.contains("DankMacShell Doctor — v0.9.9"))
        #expect(text.contains("Summary: 0 passed, 0 warnings, 0 failed, 0 info — exit code 0"))
        #expect(!report.hasFailures)
        #expect(report.recommendedExitCode == 0)
    }
}
