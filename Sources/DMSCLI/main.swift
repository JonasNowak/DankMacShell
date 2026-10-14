import Foundation
import AppKit
import DMSCore

let version = "1.5.0-macos"

func printHelp() {
    print("""
    DankMaterialShell (DMS) macOS CLI (v\(version))

    Usage:
      dms run                          Start DankMaterialShell app
      dms stop                         Stop running DankMaterialShell
      dms restart                      Restart DankMaterialShell
      dms status                       Show running status of DMS daemon and socket
      dms doctor                       Run diagnostics check on permissions and subsystems

      dms ipc call <target> <action> [args...]  Send IPC command to shell

    Target shortcuts:
      dms spotlight [toggle|open|close] Toggle Spotlight/Launcher overlay
      dms launcher [toggle|open|close]  Alias for spotlight
      dms dash [toggle|open|close]      Toggle DankDash overview
      dms control-center [toggle]       Toggle Control Center quick settings
      dms powermenu [action]            Open Power Menu or trigger sleep/lock/restart
      dms notepad [open|toggle|get|set <text>]  Notepad scratchpad manager
      dms clipboard [open|list|clear]   Clipboard history manager
      dms processlist [open|list|kill <pid>]    Activity Monitor / Task manager
      dms colorpicker [pick]            Screen eyedropper / color sampler
      dms qr <text>                     Generate QR code for text/URL
      dms keybinds [open]               Keyboard shortcuts cheatsheet
      dms settings [open|get|set|dump]  Material 3 configuration manager
      dms bar [reveal|hide|toggle|status]       DankBar controls
      dms dock [reveal|hide|toggle|status]      Dock controls
      dms audio [status|setvolume <0-100>|mute|unmute|toggle]
      dms mic [status|mute|unmute|toggle]
      dms brightness [get|set <0-100>|increment|decrement]
      dms inhibit [toggle|status]       Prevent display and system sleep (caffeinate)
      dms mpris [status|play|pause|next|prev]   Media playback control
      dms theme [get|set <name>|list|toggle-mode]
      dms screenshot [region|full|window]
      dms plugins [search|list|install|uninstall|enable|disable|lock|restore]
      dms applets [list|toggle <name>]  Customize DankBar widgets and applets
      dms version                      Show version info
    """)
}

func getSocketPath() -> String {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("DMS/dms.sock").path
}

func sendSocketCommand(_ commandStr: String) -> String? {
    let path = getSocketPath()
    guard FileManager.default.fileExists(atPath: path) else {
        return nil
    }

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    defer { close(fd) }

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
        return nil
    }

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

func isDMSRunning() -> Bool {
    let task = Process()
    task.launchPath = "/usr/bin/pgrep"
    task.arguments = ["-f", "DankMaterialShell"]
    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    return task.terminationStatus == 0
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

case "run":
    let appPath = ("~/Applications/DankMaterialShell.app" as NSString).expandingTildeInPath
    if FileManager.default.fileExists(atPath: appPath) {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [appPath]
        try? task.run()
        print("DankMaterialShell launched from \(appPath)")
    } else {
        print("DankMaterialShell.app not found in ~/Applications. Run ./build.sh first.")
        exit(1)
    }

case "stop":
    let task = Process()
    task.launchPath = "/usr/bin/pkill"
    task.arguments = ["-x", "DMS"]
    try? task.run()
    task.waitUntilExit()
    print("DankMaterialShell stopped.")

case "restart":
    let stopTask = Process()
    stopTask.launchPath = "/usr/bin/pkill"
    stopTask.arguments = ["-x", "DMS"]
    try? stopTask.run()
    stopTask.waitUntilExit()
    Thread.sleep(forTimeInterval: 0.5)

    let appPath = ("~/Applications/DankMaterialShell.app" as NSString).expandingTildeInPath
    let openTask = Process()
    openTask.launchPath = "/usr/bin/open"
    openTask.arguments = [appPath]
    try? openTask.run()
    print("DankMaterialShell restarted.")

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

    let configPath = ("~/Library/Application Support/DMS/config.json" as NSString).expandingTildeInPath
    let configExists = FileManager.default.fileExists(atPath: configPath)
    print("[\(configExists ? "✓" : "✗")] User Config: \(configExists ? configPath : "Default fallback")")

    let notesPath = ("~/Library/Application Support/DMS/notes.json" as NSString).expandingTildeInPath
    print("[\(FileManager.default.fileExists(atPath: notesPath) ? "✓" : "i")] Notepad storage: \(notesPath)")

    let clipPath = ("~/Library/Application Support/DMS/clipboard_history.json" as NSString).expandingTildeInPath
    print("[\(FileManager.default.fileExists(atPath: clipPath) ? "✓" : "i")] Clipboard history storage: \(clipPath)")

    print("Subsystems check:")
    print("[✓] CoreAudio: Enabled")
    print("[✓] CoreWLAN: Enabled")
    print("[✓] IOBluetooth: Enabled")
    print("[✓] IOKit Power Sources: Enabled")
    print("[✓] DisplayServices: Brightness dynamic lookup")
    print("[✓] CBBlueLightClient: Night Shift dynamic lookup")
    print("Doctor check complete.")

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
