import Foundation
import DMSCore

/// Enumerates running processes and provides termination controls for ProcessList modal.
@MainActor
public final class ProcessService: ObservableObject {
    public static let shared = ProcessService()

    @Published public private(set) var processes: [ProcessInfoItem] = []

    private init() {
        refresh()
    }

    public func refresh() {
        Task.detached {
            let items = Self.fetchRunningProcesses()
            await MainActor.run {
                ProcessService.shared.processes = items
            }
        }
    }

    public func killProcess(pid: Int32, force: Bool = false) -> Bool {
        let signal = force ? SIGKILL : SIGTERM
        let res = kill(pid, signal)
        refresh()
        return res == 0
    }

    nonisolated public static func fetchRunningProcesses() -> [ProcessInfoItem] {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-axo", "pid,%cpu,rss,user,comm"]

        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        var results: [ProcessInfoItem] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines.dropFirst() {
            let tokens = line.split(whereSeparator: { $0.isWhitespace })
            guard tokens.count >= 5 else { continue }

            guard let pid = Int32(tokens[0]),
                  let cpu = Double(tokens[1]),
                  let rssKB = Double(tokens[2]) else {
                continue
            }

            let user = String(tokens[3])
            let command = tokens[4...].joined(separator: " ")
            let name = (command as NSString).lastPathComponent

            // Skip zero CPU/RAM kernel threads if desired, or keep all user processes
            let memoryMB = rssKB / 1024.0
            results.append(ProcessInfoItem(pid: pid, name: name, cpuPercent: cpu, memoryMB: memoryMB, user: user))
        }

        // Sort by CPU descending by default
        return results.sorted { $0.cpuPercent > $1.cpuPercent }
    }
}
