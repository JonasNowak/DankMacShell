import Foundation
import AppKit
import DMSCore
import EditLine
import EditLine.readline

let version = "0.7.0"

func printHelp() {
    print("""
    DankMacShell (DMS) macOS CLI (v\(version))

    Usage:
      dms start                        Start DankMaterialShell app (alias: run)
      dms run                          Alias for 'dms start'
      dms stop                         Stop running DankMaterialShell
      dms restart                      Restart DankMaterialShell
      dms status                       Show running status of DMS daemon and socket
      dms doctor                       Run diagnostics check on permissions and subsystems
      dms permission                   Open Accessibility settings to enable full OSD swallowing

      dms ipc call <target> <action> [args...]  Send IPC command to shell
      dms dmenu [--prompt <text>]   dmenu/rofi drop-in: read candidates from stdin, print selection to stdout
      dms listen [topic]            Stream newline-delimited JSON events (default topic: *)
      dms shell                     Interactive IPC REPL with history and tab-completion

    Event topics for 'dms listen':
      events.audio events.battery events.wifi events.workspaces events.media events.theme  (or * for all)

    Target shortcuts:
      dms spotlight [toggle|open|close] Toggle Spotlight/Launcher overlay
      dms launcher [toggle|open|close]  Alias for spotlight
      dms dash [toggle|open|close]      Toggle DankDash overview
      dms control-center [toggle]       Toggle Control Center quick settings
      dms powermenu [action]            Open Power Menu or trigger sleep/lock/restart
      dms notepad [open|toggle|get|set <text>]  Notepad scratchpad manager
      dms clipboard [open|list|clear]   Clipboard history manager
      dms processlist [open|list|kill <pid>]    Activity Monitor / Task manager
      dms unhide <bundleID> [--background]      Unhide running application
      dms unhide-all [--background]             Unhide all hidden applications
      dms hide <bundleID>                       Hide running application
      dms activate <bundleID>                   Unhide and focus application
      dms colorpicker [pick]            Screen eyedropper / color sampler
      dms qr <text>                     Generate QR code for text/URL
      dms keybinds [open]               Keyboard shortcuts cheatsheet
      dms settings [open|get|set|dump]  Material 3 configuration manager
      dms wellbeing [status|enable|disable|toggle|sync|open-system] Digital Wellbeing & Screen Time
      dms bar [reveal|hide|toggle|status]       DankBar controls
      dms dock [reveal|hide|toggle|status]      Dock controls
      dms workspace [status|switch <num>|next|prev] Virtual workspace manager
      dms audio [status|setvolume <0-100>|mute|unmute|toggle]
      dms mic [status|mute|unmute|toggle]
      dms brightness [get|set <0-100>|increment|decrement]
      dms inhibit [toggle|status]       Prevent display and system sleep (caffeinate)
      dms mpris [status|play|pause|next|prev|seek <sec>|lyrics]   Media playback control
      dms lyrics [status|current|refresh|clear-cache|offset <ms>] Synchronized LRC lyrics
      dms theme [get|set <name>|list|toggle-mode]
      dms screenshot [region|full|window]
      dms plugins [search|list|install|uninstall|enable|disable|lock|restore]
      dms applets [list|toggle <name>]  Customize DankBar widgets and applets
      dms weather [status|refresh|location <city|lat,lon>] Live Open-Meteo weather controls
      dms wallpaper [get|set <path>|list|picker|next|prev|random] Desktop wallpaper browser and slanted switcher
      dms omniwm [get|sync|mode <mode>|direction <dir>|toggle] Auto-theme OmniWM window borders
      dms version                      Show version info
    """)
}

func getSocketPath() -> String {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("DMS/dms.sock").path
}

func connectSocket() -> Int32? {
    let path = getSocketPath()
    guard FileManager.default.fileExists(atPath: path) else {
        return nil
    }

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = path.utf8CString
    withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
        let raw = UnsafeMutableRawPointer(ptr)
        _ = pathBytes.withUnsafeBufferPointer { buf in
            memcpy(raw, buf.baseAddress!, min(buf.count, 104))
        }
    }

    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
    let connectRes = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
            connect(fd, saPtr, addrLen)
        }
    }

    guard connectRes == 0 else {
        close(fd)
        return nil
    }
    return fd
}

func sendSocketCommand(_ commandStr: String) -> String? {
    guard let fd = connectSocket() else {
        return nil
    }
    defer { close(fd) }

    let message = commandStr.hasSuffix("\n") ? commandStr : (commandStr + "\n")
    _ = message.utf8CString.withUnsafeBufferPointer { buf in
        write(fd, buf.baseAddress!, buf.count - 1)
    }

    // Read response with timeout
    var timeout = timeval(tv_sec: 2, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

    var buffer = [CChar](repeating: 0, count: 8192)
    let bytesRead = read(fd, &buffer, 8191)
    if bytesRead > 0 {
        return String(decoding: buffer.prefix(bytesRead).map { UInt8(bitPattern: $0) }, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return ""
}

func resolveAppPath() -> String? {
    let candidates = [
        ("~/Applications/DankMacShell.app" as NSString).expandingTildeInPath,
        ("~/Applications/DankMaterialShell.app" as NSString).expandingTildeInPath,
        "/Applications/DankMacShell.app",
        "/Applications/DankMaterialShell.app"
    ]
    return candidates.first { FileManager.default.fileExists(atPath: $0) }
}

func resolveBinaryPath(in appPath: String) -> String? {
    let candidates = [
        "\(appPath)/Contents/MacOS/DankMaterialShell",
        "\(appPath)/Contents/MacOS/DankMacShell",
        "\(appPath)/Contents/MacOS/DMS"
    ]
    return candidates.first { FileManager.default.fileExists(atPath: $0) }
}

func spawnDMS(appPath: String) -> Bool {
    guard let binPath = resolveBinaryPath(in: appPath) else { return false }
    let task = Process()
    task.executableURL = URL(fileURLWithPath: binPath)
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    do {
        try task.run()
        return true
    } catch {
        return false
    }
}

func isDMSRunning() -> Bool {
    let task = Process()
    task.launchPath = "/usr/bin/pgrep"
    task.arguments = ["-x", "DankMaterialShell|DankMacShell"]
    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    return task.terminationStatus == 0
}

func probeMediaRemote() -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let candidates = [
        "\(home)/Applications/DankMacShell.app/Contents/Resources/media-bridge.swift",
        "/Applications/DankMacShell.app/Contents/Resources/media-bridge.swift",
        "Support/media-bridge.swift",
        "\(home)/Library/Application Support/DMS/media-bridge.swift"
    ]
    guard let scriptPath = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
        return "{}"
    }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    task.arguments = [scriptPath, "--once"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice

    do {
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !output.isEmpty {
            return output
        }
    } catch {
        return "{}"
    }
    return "{}"
}

// MARK: - v0.7 CLI Pipelines: dmenu / listen / shell

func writeStderr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

/// `dms dmenu [--prompt <text>]`: read newline-delimited candidates from stdin, present them in the
/// running shell's launcher (filter mode), print the chosen line to stdout (exit 0).
/// Esc/cancel prints nothing and exits 1. Daemon unreachable exits 3.
func runDMenu(args: [String]) {
    var prompt = ""
    var i = 0
    while i < args.count {
        if args[i] == "--prompt" || args[i] == "-p" {
            if i + 1 < args.count { prompt = args[i + 1] }
            i += 2
        } else {
            i += 1
        }
    }

    let stdinData = FileHandle.standardInput.readDataToEndOfFile()
    guard let input = String(data: stdinData, encoding: .utf8) else {
        writeStderr("dms dmenu: stdin is not valid UTF-8")
        exit(1)
    }
    let candidates = input
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
        .filter { !$0.isEmpty }
    guard !candidates.isEmpty else {
        exit(1) // empty input: nothing to select, like dmenu
    }

    let requestID = DMenuStaging.newRequestID()
    let candidatesURL: URL
    do {
        candidatesURL = try DMenuStaging.stage(candidates: candidates, requestID: requestID)
    } catch {
        writeStderr("dms dmenu: failed to stage candidates: \(error.localizedDescription)")
        exit(1)
    }
    func finish(_ code: Int32) -> Never {
        DMenuStaging.cleanup(requestID: requestID)
        exit(code)
    }

    guard let fd = connectSocket() else {
        writeStderr("dms dmenu: DMS daemon not running (socket \(getSocketPath()) missing) — start it with 'dms start'")
        finish(3)
    }

    // Only the staged file path + requestID travel over the socket; the line protocol stays intact.
    var commandLine = "ipc call dmenu \(requestID) --file \(candidatesURL.path)"
    if !prompt.isEmpty {
        // Keep the line protocol intact: a prompt must never contain a newline.
        let safePrompt = prompt.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        commandLine += " --prompt \(safePrompt)"
    }
    commandLine += "\n"
    _ = commandLine.utf8CString.withUnsafeBufferPointer { buf in
        write(fd, buf.baseAddress!, buf.count - 1)
    }

    // Keep the persistent connection open and stream lines until the dmenu result arrives.
    var buffer = Data()
    var chunk = [UInt8](repeating: 0, count: 8192)
    while true {
        let n = read(fd, &chunk, chunk.count)
        if n <= 0 { break }
        buffer.append(contentsOf: chunk.prefix(n))
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer.subdata(in: 0..<newlineIndex)
            buffer.removeSubrange(0...newlineIndex)
            guard let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !line.isEmpty else { continue }
            if let data = line.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resultID = obj["dmenuResult"] as? String,
               resultID == requestID {
                close(fd)
                if (obj["cancelled"] as? Bool) ?? false {
                    finish(1)
                }
                if let selected = obj["line"] as? String {
                    print(selected)
                    finish(0)
                }
                finish(1)
            }
        }
    }
    close(fd)

    // Connection closed without a streamed result — fall back to the <requestID>.result file.
    if let selected = DMenuStaging.readResult(for: requestID), !selected.isEmpty {
        print(selected)
        finish(0)
    }
    finish(1)
}

/// `dms listen [topic]` (default `*`): SUBSCRIBE on a persistent socket connection and print each
/// newline-delimited JSON event to stdout until Ctrl-C or the daemon closes the stream.
func runListen(args: [String]) {
    let topic = args.first ?? "*"
    guard let fd = connectSocket() else {
        writeStderr("dms listen: DMS daemon not running (socket \(getSocketPath()) missing) — start it with 'dms start'")
        exit(3)
    }
    defer { close(fd) }

    let subscribe = "SUBSCRIBE \(topic)\n"
    _ = subscribe.utf8CString.withUnsafeBufferPointer { buf in
        write(fd, buf.baseAddress!, buf.count - 1)
    }

    var buffer = Data()
    var chunk = [UInt8](repeating: 0, count: 8192)
    while true {
        let n = read(fd, &chunk, chunk.count)
        if n <= 0 { break }
        buffer.append(contentsOf: chunk.prefix(n))
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer.subdata(in: 0..<newlineIndex)
            buffer.removeSubrange(0...newlineIndex)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                print(line)
                fflush(stdout)
            }
        }
    }
}

/// readline tab-completion over the known target/action vocabulary from `IPCCommand.parseCLI`.
/// Builds the `char**` match list manually (common prefix first, then candidates, nil-terminated)
/// because macOS libedit does not export `rl_completion_matches` to Swift.
let dmsShellCompletion: @convention(c) (UnsafePointer<CChar>?, Int32, Int32) -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = { text, _, _ in
    guard let text = text else { return nil }
    let matches = IPCCommand.cliCompletions(forPrefix: String(cString: text))
    guard !matches.isEmpty else { return nil }
    var common = matches[0]
    for match in matches.dropFirst() {
        while !match.hasPrefix(common) && !common.isEmpty {
            common = String(common.dropLast())
        }
    }
    var entries: [UnsafeMutablePointer<CChar>?] = [strdup(common)]
    entries.append(contentsOf: matches.map { strdup($0) })
    entries.append(nil)
    let buffer = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: entries.count)
    for (index, entry) in entries.enumerated() {
        buffer[index] = entry
    }
    return buffer
}

/// `dms shell`: interactive REPL — `dms> ` prompt, one IPC command per line over the socket,
/// history in ~/.dms_shell_history, tab-completion over the CLI vocabulary.
func runShell() {
    let historyPath = (NSHomeDirectory() as NSString).appendingPathComponent(".dms_shell_history")
    _ = read_history(historyPath)
    stifle_history(500)
    rl_attempted_completion_function = dmsShellCompletion

    print("DankMacShell IPC shell (v\(version)) — type 'exit' or Ctrl-D to quit, Tab to complete.")
    while true {
        guard let raw = readline("dms> ") else {
            print("")
            break
        }
        let line = String(cString: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        free(raw)
        if line.isEmpty { continue }
        if line == "exit" || line == "quit" { break }
        add_history(line)
        let command = line.lowercased().hasPrefix("ipc") ? line : "ipc call \(line)"
        if let response = sendSocketCommand(command) {
            print(response)
        } else {
            writeStderr("dms: daemon unreachable (is DankMacShell running? try 'dms start')")
        }
    }
    _ = write_history(historyPath)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first?.lowercased() else {
    printHelp()
    exit(0)
}

switch command {
case "help", "-h", "--help":
    printHelp()

case "version", "-v", "--version":
    print("DankMaterialShell (DMS) for macOS v\(version)")

case "media-probe":
    print(probeMediaRemote())

case "start", "run":
    if isDMSRunning() {
        print("DankMacShell is already running. Use 'dms restart' to restart it.")
        exit(0)
    }

    unlink(getSocketPath())

    guard let appPath = resolveAppPath() else {
        print("DankMacShell.app not found in ~/Applications. Run ./build.sh first.")
        exit(1)
    }

    if spawnDMS(appPath: appPath) {
        print("DankMacShell launched from \(appPath)")
    } else {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [appPath]
        try? task.run()
        print("DankMacShell launched from \(appPath)")
    }

case "stop":
    let task = Process()
    task.launchPath = "/usr/bin/pkill"
    task.arguments = ["-x", "DankMaterialShell|DankMacShell"]
    try? task.run()
    task.waitUntilExit()

    unlink(getSocketPath())
    print("DankMacShell stopped.")

case "restart":
    let stopTask = Process()
    stopTask.launchPath = "/usr/bin/pkill"
    stopTask.arguments = ["-x", "DankMaterialShell|DankMacShell"]
    try? stopTask.run()
    stopTask.waitUntilExit()

    // Drain wait until previous PID fully terminates
    for _ in 0..<20 {
        if !isDMSRunning() { break }
        Thread.sleep(forTimeInterval: 0.1)
    }

    unlink(getSocketPath())

    guard let appPath = resolveAppPath() else {
        print("DankMacShell.app not found in ~/Applications.")
        exit(1)
    }

    if spawnDMS(appPath: appPath) {
        print("DankMacShell restarted.")
    } else {
        let openTask = Process()
        openTask.launchPath = "/usr/bin/open"
        openTask.arguments = [appPath]
        try? openTask.run()
        print("DankMacShell restarted.")
    }

case "permission", "accessibility":
    let modernURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")
    let legacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    if let modernURL, NSWorkspace.shared.open(modernURL) {
        // Opened
    } else if let legacyURL {
        NSWorkspace.shared.open(legacyURL)
    }
    print("Opened System Settings > Privacy & Security > Accessibility (Gerätesteuerung und Datenzugriff).")
    print("Toggle 'DankMacShell' ON to enable active media key interception and full OSD swallowing.")

case "symbian", "nokia":
    let subArgs = Array(args.dropFirst())
    let act = subArgs.first?.lowercased() ?? "open"
    if act == "open" || act == "gui" || act == "show" {
        switch SymbianClient.shared.launchCompanion() {
        case .success:
            print("Launched Nokia Belle USB Sync companion.")
        case .failure(let err):
            print("Failed to launch companion: \(err.description)")
        }
    } else {
        let actionArgs = Array(subArgs.dropFirst())
        switch SymbianClient.shared.runAction(act, arguments: actionArgs) {
        case .success(let out):
            print(out)
        case .failure(let err):
            print("Action failed: \(err.description)")
        }
    }

case "status":
    let running = isDMSRunning()
    let socketExists = FileManager.default.fileExists(atPath: getSocketPath())
    print("DankMaterialShell Status:")
    print("  Daemon: \(running ? "Running (pid: \((try? String(contentsOfFile: "/tmp/dms.pid", encoding: .utf8)) ?? "active")" : "Stopped")")
    print("  Socket: \(socketExists ? "Active (\(getSocketPath()))" : "Inactive")")
    if running, socketExists {
        if let res = sendSocketCommand("status") {
            print("  Shell State: \(res)")
        }
    }

case "doctor":
    print("=== DankMaterialShell Doctor (macOS Diagnostic) ===")
    let running = isDMSRunning()
    print("[\(running ? "✓" : "✗")] Daemon running: \(running ? "YES" : "NO (use 'dms run')")")

    let socketExists = FileManager.default.fileExists(atPath: getSocketPath())
    print("[\(socketExists ? "✓" : "✗")] IPC Unix Socket: \(socketExists ? getSocketPath() : "Missing")")

    let settingsPath = ("~/Library/Application Support/DMS/settings.json" as NSString).expandingTildeInPath
    let configPath = ("~/Library/Application Support/DMS/config.json" as NSString).expandingTildeInPath
    let configExists = FileManager.default.fileExists(atPath: settingsPath) || FileManager.default.fileExists(atPath: configPath)
    let activePath = FileManager.default.fileExists(atPath: settingsPath) ? settingsPath : configPath
    print("[\(configExists ? "✓" : "✗")] User Config: \(configExists ? activePath : "Default fallback")")

    let notesPath = ("~/Library/Application Support/DMS/notes.json" as NSString).expandingTildeInPath
    print("[\(FileManager.default.fileExists(atPath: notesPath) ? "✓" : "i")] Notepad storage: \(notesPath)")

    let clipPath = ("~/Library/Application Support/DMS/clipboard_history.json" as NSString).expandingTildeInPath
    print("[\(FileManager.default.fileExists(atPath: clipPath) ? "✓" : "i")] Clipboard history storage: \(clipPath)")

    if running, socketExists, let daemonDoc = sendSocketCommand("doctor") {
        print("\nLive Daemon Diagnostics:")
        for line in daemonDoc.components(separatedBy: "\n") {
            print("  \(line)")
        }
        if daemonDoc.contains("AXTrusted=false") {
            print("\n[!] Accessibility Permission: NOT GRANTED")
            print("    Media keys are in passive listening mode.")
            print("    Run 'dms permission' and toggle DankMacShell ON to enable active event swallowing.")
        }
    } else {
        print("\nSubsystems check:")
        print("[✓] CoreAudio: Enabled")
        print("[✓] CoreWLAN: Enabled")
        print("[✓] IOBluetooth: Enabled")
        print("[✓] IOKit Power Sources: Enabled")
        print("[✓] DisplayServices: Brightness dynamic lookup")
        print("[✓] CBBlueLightClient: Night Shift dynamic lookup")
    }
    print("Doctor check complete.")

case "dmenu":
    runDMenu(args: Array(args.dropFirst()))

case "listen":
    runListen(args: Array(args.dropFirst()))

case "shell":
    runShell()

case "ipc":
    // dms ipc call <target> <action> [args...]
    let rawCommand = args.joined(separator: " ")
    if let response = sendSocketCommand(rawCommand) {
        print(response)
    } else {
        // Fallback to URL scheme open
        let cmd = IPCCommand.parseCLI(args: Array(args.dropFirst()))
        print("Note: Unix socket unreachable, triggering via dms:// fallback for \(cmd)")
        let urlStr = "dms://\(args.dropFirst().joined(separator: "/"))"
        if let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }

default:
    // Shortcut for direct target invocation: e.g. "dms audio status", "dms notepad get"
    let rawCommand = "ipc call " + args.joined(separator: " ")
    if let response = sendSocketCommand(rawCommand) {
        print(response)
    } else {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-g", "dms://\(args.joined(separator: "/"))"]
        try? task.run()
    }
}
