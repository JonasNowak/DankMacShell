import Foundation
import AppKit
import DMSCore
import EditLine
import EditLine.readline

let version = DMSVersion.current

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
      dms permission                   Open Device Control and Data Access settings to enable full OSD swallowing
      dms setup-cert                   Create/trust persistent 'dms-cert' and re-sign DankMacShell.app for TCC persistence
      dms onboard                      Re-open the first-run onboarding flow (alias: onboarding)

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

/// Writes the whole string to the socket, handling partial writes and EINTR.
func writeAll(_ fd: Int32, _ string: String) {
    let bytes = [UInt8](string.utf8)
    var offset = 0
    while offset < bytes.count {
        let n = bytes.withUnsafeBufferPointer { buf in
            write(fd, buf.baseAddress! + offset, buf.count - offset)
        }
        if n > 0 {
            offset += n
        } else if n < 0 && errno == EINTR {
            continue
        } else {
            break
        }
    }
}

func sendSocketCommand(_ commandStr: String) -> String? {
    guard let fd = connectSocket() else {
        return nil
    }
    defer { close(fd) }

    let message = commandStr.hasSuffix("\n") ? commandStr : (commandStr + "\n")
    writeAll(fd, message)

    // Read timeout: 10s for regular commands, 120s for long-running ones (symbian/wifi/wallpaper).
    let lower = commandStr.lowercased()
    let longRunning = lower.contains("symbian") || lower.contains("wifi") || lower.contains("wallpaper")
    var timeout = timeval(tv_sec: longRunning ? 120 : 10, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

    // Read until EOF (the daemon closes one-shot connections after responding), capped at 4 MB.
    var result = Data()
    let cap = 4 * 1024 * 1024
    var chunk = [UInt8](repeating: 0, count: 8192)
    while result.count < cap {
        let n = read(fd, &chunk, chunk.count)
        if n > 0 {
            result.append(contentsOf: chunk.prefix(n))
        } else if n == 0 {
            break // EOF
        } else if errno == EINTR {
            continue
        } else {
            break // timeout or error
        }
    }
    guard !result.isEmpty else { return "" }
    return String(decoding: result, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Returns 1 when the daemon replied with a JSON error envelope, nil otherwise.
func daemonErrorExitCode(for response: String) -> Int32? {
    guard let data = response.data(using: .utf8),
          let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let status = obj["status"] as? String,
          status == "error" else {
        return nil
    }
    return 1
}

/// Sends a command to the daemon, prints the response, and exits non-zero on failure:
/// 3 when the daemon is unreachable, 1 when the daemon reports an error.
func sendAndPrint(_ commandStr: String) -> Never {
    guard let response = sendSocketCommand(commandStr) else {
        writeStderr("dms: daemon unreachable (socket \(getSocketPath()) missing) — is DankMacShell running? try 'dms start'")
        exit(3)
    }
    print(response)
    if let code = daemonErrorExitCode(for: response) {
        exit(code)
    }
    exit(0)
}

func resolveAppPath() -> String? {
    let fm = FileManager.default
    if let envPath = ProcessInfo.processInfo.environment["DMS_APP_PATH"],
       !envPath.isEmpty,
       fm.fileExists(atPath: envPath) {
        return envPath
    }

    var candidates: [String] = []
    if let exeURL = Bundle.main.executableURL?.resolvingSymlinksInPath() {
        let macOSDir = exeURL.deletingLastPathComponent()
        let contentsDir = macOSDir.deletingLastPathComponent()
        let bundleDir = contentsDir.deletingLastPathComponent()
        if macOSDir.lastPathComponent == "MacOS",
           contentsDir.lastPathComponent == "Contents",
           bundleDir.pathExtension == "app" {
            candidates.append(bundleDir.path)
        }
    }

    candidates.append(contentsOf: [
        ("~/Applications/DankMacShell.app" as NSString).expandingTildeInPath,
        ("~/Applications/DankMaterialShell.app" as NSString).expandingTildeInPath,
        "/Applications/DankMacShell.app",
        "/Applications/DankMaterialShell.app",
        "/Applications/Nix Apps/DankMacShell.app",
        ("~/Applications/Home Manager Apps/DankMacShell.app" as NSString).expandingTildeInPath
    ])
    return candidates.first { fm.fileExists(atPath: $0) }
}

func setupPersistentCertAndSign(targetAppPath: String? = nil) -> Int32 {
    guard let appPath = targetAppPath ?? resolveAppPath() else {
        writeStderr("dms setup-cert: DankMacShell.app not found in ~/Applications or /Applications.")
        return 1
    }

    // Validate the target: an existing, writable .app bundle (never a read-only /nix/store path).
    var isDir: ObjCBool = false
    guard appPath.hasSuffix(".app"),
          FileManager.default.fileExists(atPath: appPath, isDirectory: &isDir),
          isDir.boolValue else {
        writeStderr("dms setup-cert: '\(appPath)' is not an existing .app bundle.")
        return 1
    }
    if appPath.hasPrefix("/nix/store") {
        writeStderr("dms setup-cert: refusing to sign read-only /nix/store path '\(appPath)'. Copy the .app to ~/Applications first.")
        return 1
    }
    guard FileManager.default.isWritableFile(atPath: appPath) else {
        writeStderr("dms setup-cert: '\(appPath)' is not writable by the current user.")
        return 1
    }

    /// Runs a subprocess and requires exit status 0.
    func runChecked(_ exe: String, _ arguments: [String], what: String) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: exe)
        proc.arguments = arguments
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            writeStderr("dms setup-cert: failed to launch \(what): \(error.localizedDescription)")
            return false
        }
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            writeStderr("dms setup-cert: \(what) exited with status \(proc.terminationStatus)")
            return false
        }
        return true
    }

    let certName = "dms-cert"
    let keychain = ("~/Library/Keychains/login.keychain-db" as NSString).expandingTildeInPath

    // Check if dms-cert already exists in codesigning identities
    let checkTask = Process()
    checkTask.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    checkTask.arguments = ["find-identity", "-p", "codesigning", "-v"]
    let checkPipe = Pipe()
    checkTask.standardOutput = checkPipe
    checkTask.standardError = FileHandle.nullDevice
    try? checkTask.run()
    checkTask.waitUntilExit()
    let checkOut = String(data: checkPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    if !checkOut.contains("\"\(certName)\"") {
        print("==> Creating persistent self-signed code signing certificate '\(certName)'...")
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dms-cert-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tmpDir.path)
        } catch {
            writeStderr("dms setup-cert: failed to create private temp dir: \(error.localizedDescription)")
            return 1
        }
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Random 32-hex passphrase in a 0600 passfile — never a hardcoded password.
        let passphrase = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(32))
        let passfilePath = tmpDir.appendingPathComponent("passfile").path
        do {
            try passphrase.write(toFile: passfilePath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: passfilePath)
        } catch {
            writeStderr("dms setup-cert: failed to write passfile: \(error.localizedDescription)")
            return 1
        }

        let cnfPath = tmpDir.appendingPathComponent("cert.cnf").path
        let keyPath = tmpDir.appendingPathComponent("key.pem").path
        let certPath = tmpDir.appendingPathComponent("cert.pem").path
        let p12Path = tmpDir.appendingPathComponent("cert.p12").path

        let cnf = """
        [ req ]
        distinguished_name = req_distinguished_name
        prompt = no
        x509_extensions = v3_ca

        [ req_distinguished_name ]
        CN = dms-cert

        [ v3_ca ]
        basicConstraints = critical,CA:FALSE
        keyUsage = critical,digitalSignature
        extendedKeyUsage = critical,codeSigning
        """
        try? cnf.write(toFile: cnfPath, atomically: true, encoding: .utf8)

        guard runChecked("/usr/bin/openssl",
                         ["req", "-x509", "-newkey", "rsa:2048", "-keyout", keyPath, "-out", certPath, "-days", "3650", "-nodes", "-config", cnfPath],
                         what: "openssl req") else { return 1 }
        guard runChecked("/usr/bin/openssl",
                         ["pkcs12", "-export", "-inkey", keyPath, "-in", certPath, "-out", p12Path, "-passout", "file:\(passfilePath)", "-name", certName],
                         what: "openssl pkcs12") else { return 1 }
        guard runChecked("/usr/bin/security",
                         ["import", p12Path, "-k", keychain, "-P", passphrase, "-T", "/usr/bin/codesign"],
                         what: "security import") else { return 1 }
        guard runChecked("/usr/bin/security",
                         ["add-trusted-cert", "-r", "trustRoot", "-p", "codeSign", "-k", keychain, certPath],
                         what: "security add-trusted-cert") else { return 1 }
    }

    guard runChecked("/usr/bin/xattr", ["-cr", "--", appPath], what: "xattr") else { return 1 }

    print("==> Signing \(appPath) with identity '\(certName)'...")
    guard runChecked("/usr/bin/codesign",
                     ["--force", "--deep", "--sign", certName, "--", appPath],
                     what: "codesign") else { return 1 }
    print("==> Signed \(appPath) with '\(certName)' (TCC permissions will persist across updates).")
    return 0
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

/// Live PIDs of running DMS daemon processes (pgrep — no stale pidfile).
func dmsPIDs() -> [Int32] {
    let task = Process()
    task.launchPath = "/usr/bin/pgrep"
    task.arguments = ["-x", "DankMaterialShell|DankMacShell"]
    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return out.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
}

func isDMSRunning() -> Bool {
    !dmsPIDs().isEmpty
}

func probeMediaRemote() -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    var candidates: [String] = []
    // Resolve via the app bundle — never a relative CWD path.
    if let appPath = resolveAppPath() {
        candidates.append("\(appPath)/Contents/Resources/media-bridge.swift")
    }
    candidates.append(contentsOf: [
        "\(home)/Applications/DankMacShell.app/Contents/Resources/media-bridge.swift",
        "/Applications/DankMacShell.app/Contents/Resources/media-bridge.swift",
        "\(home)/Library/Application Support/DMS/media-bridge.swift"
    ])
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
    do {
        // Stage the candidates where the daemon expects them (derived from the requestID).
        _ = try DMenuStaging.stage(candidates: candidates, requestID: requestID)
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

    // Only the requestID (+ optional prompt) travel over the socket; the daemon derives the
    // staged candidates path server-side. Never send `--file <path>`: the staging directory
    // lives under "Application Support" (contains a space), which broke whitespace tokenization.
    var commandLine = "ipc call dmenu \(requestID)"
    if !prompt.isEmpty {
        // Keep the line protocol intact: a prompt must never contain a newline.
        let safePrompt = prompt.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        commandLine += " --prompt \(safePrompt)"
    }
    commandLine += "\n"
    writeAll(fd, commandLine)

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
    var topic = args.first ?? "*"
    // A topic must never break the line protocol.
    if topic.contains("\r") || topic.contains("\n") {
        writeStderr("dms listen: topic contains CR/LF — stripping")
        topic = topic.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
    }
    if topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { topic = "*" }

    guard let fd = connectSocket() else {
        writeStderr("dms listen: DMS daemon not running (socket \(getSocketPath()) missing) — start it with 'dms start'")
        exit(3)
    }
    defer { close(fd) }

    writeAll(fd, "SUBSCRIBE \(topic)\n")

    var buffer = Data()
    let maxBuffer = 4 * 1024 * 1024
    var chunk = [UInt8](repeating: 0, count: 8192)
    var sawAck = false
    while true {
        let n = read(fd, &chunk, chunk.count)
        if n <= 0 {
            if !sawAck {
                writeStderr("dms listen: disconnected before subscribe ack")
            } else {
                writeStderr("dms listen: daemon closed the stream unexpectedly")
            }
            exit(1)
        }
        buffer.append(contentsOf: chunk.prefix(n))
        if buffer.count > maxBuffer {
            writeStderr("dms listen: read buffer exceeded 4 MB cap — aborting")
            exit(1)
        }
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer.subdata(in: 0..<newlineIndex)
            buffer.removeSubrange(0...newlineIndex)
            guard let line = String(data: lineData, encoding: .utf8), !line.isEmpty else { continue }
            if !sawAck {
                // The subscribe ack goes to stderr so stdout stays a pure event stream.
                sawAck = true
                writeStderr("dms listen: \(line)")
                continue
            }
            print(line)
            fflush(stdout)
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
    // C calloc (zero-initialized, nil-terminated) instead of Swift allocate.
    let buffer = calloc(entries.count, MemoryLayout<UnsafeMutablePointer<CChar>?>.size)
        .assumingMemoryBound(to: UnsafeMutablePointer<CChar>?.self)
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

    print("DankMacShell IPC shell (v\(version)) — type 'exit' or Ctrl-D to quit, 'help' for commands, Tab to complete.")
    while true {
        guard let raw = readline("dms> ") else {
            print("")
            break
        }
        let line = String(cString: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        free(raw)
        if line.isEmpty { continue }
        if line == "exit" || line == "quit" { break }
        let lower = line.lowercased()
        if lower == "help" || lower == "?" {
            print("""
            Commands:
              <target> <action> [args...]   IPC command (e.g. 'launcher toggle', 'settings get theme')
              ipc call <target> ...         explicit IPC form
              GET|POST|PUT|DELETE /path     REST request (e.g. 'GET /api/v1/audio/volume')
              SUBSCRIBE <topic>             subscribe to an event stream on this connection
              version                       show CLI version
              exit / quit                   leave the shell
            """)
            continue
        }
        if lower == "version" {
            print("DankMaterialShell (DMS) for macOS v\(version)")
            continue
        }
        add_history(line)
        // Raw protocol lines (REST, SUBSCRIBE, explicit ipc) go through unprefixed;
        // everything else is wrapped as an IPC call.
        let isRawProtocol = lower.hasPrefix("ipc")
            || lower.hasPrefix("get ") || lower.hasPrefix("post ")
            || lower.hasPrefix("put ") || lower.hasPrefix("delete ")
            || lower.hasPrefix("subscribe ") || lower.hasPrefix("unsubscribe ")
        let command = isRawProtocol ? line : "ipc call \(line)"
        if let response = sendSocketCommand(command) {
            print(response)
            if let code = daemonErrorExitCode(for: response) {
                writeStderr("dms: daemon error (exit \(code))")
            }
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
    // pkill -x matches the pattern literally ("|" is not an alternation),
    // so each process name needs its own pkill invocation.
    for processName in ["DankMaterialShell", "DankMacShell"] {
        let task = Process()
        task.launchPath = "/usr/bin/pkill"
        task.arguments = ["-x", processName]
        try? task.run()
        task.waitUntilExit()
    }

    // Wait up to 3s for the daemon to exit (and remove its own socket) before unlinking.
    for _ in 0..<30 {
        if dmsPIDs().isEmpty { break }
        Thread.sleep(forTimeInterval: 0.1)
    }

    let sockPath = getSocketPath()
    var st = stat()
    if lstat(sockPath, &st) == 0 && (st.st_mode & S_IFMT) == S_IFSOCK {
        unlink(sockPath)
    }
    print("DankMacShell stopped.")

case "restart":
    // pkill -x matches the pattern literally ("|" is not an alternation),
    // so each process name needs its own pkill invocation.
    for processName in ["DankMaterialShell", "DankMacShell"] {
        let stopTask = Process()
        stopTask.launchPath = "/usr/bin/pkill"
        stopTask.arguments = ["-x", processName]
        try? stopTask.run()
        stopTask.waitUntilExit()
    }

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
    print("Opened System Settings > Privacy & Security > Device Control and Data Access (Gerätesteuerung und Datenzugriff).")
    print("Toggle 'DankMacShell' ON to enable active media key interception and full OSD swallowing.")

case "setup-cert", "cert":
    let target = args.dropFirst().first
    exit(setupPersistentCertAndSign(targetAppPath: target))

case "symbian", "nokia":
    let subArgs = Array(args.dropFirst())
    let act = subArgs.first?.lowercased() ?? "open"
    if act == "close" || act == "toggle" {
        // dms-symbian has no close/toggle verbs — route over IPC to the daemon.
        sendAndPrint("ipc call symbian \(act)")
    } else if act == "open" || act == "gui" || act == "show" {
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
    let pids = dmsPIDs()
    let running = !pids.isEmpty
    let socketExists = FileManager.default.fileExists(atPath: getSocketPath())
    print("DankMaterialShell Status:")
    print("  Daemon: \(running ? "Running (pid: \(pids.map(String.init).joined(separator: ", ")))" : "Stopped")")
    print("  Socket: \(socketExists ? "Active (\(getSocketPath()))" : "Inactive")")
    if running, socketExists {
        if let res = sendSocketCommand("status") {
            print("  Shell State: \(res)")
        }
    }
    if !running {
        exit(1)
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
            print("\n[!] Device Control and Data Access Permission: NOT GRANTED")
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

case "onboard", "onboarding":
    sendAndPrint("ipc call onboard")

case "ipc":
    // dms ipc call <target> <action> [args...]
    sendAndPrint(args.joined(separator: " "))

default:
    // Shortcut for direct target invocation: e.g. "dms audio status", "dms notepad get"
    sendAndPrint("ipc call " + args.joined(separator: " "))
}
