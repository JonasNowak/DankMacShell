import Foundation

// MARK: - MediaRemote Dynamic Bridge Worker
// Runs under /usr/bin/swift (Apple-signed) to retain system-level MediaRemote entitlements
// for full visibility into TIDAL, Zen, Firefox, YouTube, VLC, Spotify, Apple Music, etc.

let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
guard let handle = handle else {
    fputs("{\"error\":\"dlopen failed\"}\n", stderr)
    exit(1)
}

typealias MRRegister = @convention(c) (DispatchQueue) -> Void
typealias MRGetInfo = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
typealias MRGetClient = @convention(c) (DispatchQueue, @escaping (AnyObject?) -> Void) -> Void
typealias MRClientGetName = @convention(c) (AnyObject) -> CFString?
typealias MRClientGetBundle = @convention(c) (AnyObject) -> CFString?
typealias MRGetPID = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
typealias MRGetIsPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
typealias MRSendCommand = @convention(c) (Int32, AnyObject?) -> Bool
typealias MRSetElapsed = @convention(c) (Double) -> Void

guard let symReg = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications"),
      let symInfo = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
    fputs("{\"error\":\"symbols missing\"}\n", stderr)
    exit(1)
}

let mrReg = unsafeBitCast(symReg, to: MRRegister.self)
let mrGetInfo = unsafeBitCast(symInfo, to: MRGetInfo.self)
let mrGetClient = dlsym(handle, "MRMediaRemoteGetNowPlayingClient").map { unsafeBitCast($0, to: MRGetClient.self) }
let mrClientGetName = dlsym(handle, "MRNowPlayingClientGetDisplayName").map { unsafeBitCast($0, to: MRClientGetName.self) }
let mrClientGetBundle = dlsym(handle, "MRNowPlayingClientGetBundleIdentifier").map { unsafeBitCast($0, to: MRClientGetBundle.self) }
let mrGetPID = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID").map { unsafeBitCast($0, to: MRGetPID.self) }
let mrGetIsPlaying = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying").map { unsafeBitCast($0, to: MRGetIsPlaying.self) }
let mrSendCommand = dlsym(handle, "MRMediaRemoteSendCommand").map { unsafeBitCast($0, to: MRSendCommand.self) }
let mrSetElapsed = dlsym(handle, "MRMediaRemoteSetElapsedTime").map { unsafeBitCast($0, to: MRSetElapsed.self) }

// Artwork goes to a private 0700 cache dir via unique temp file + atomic rename,
// never to a predictable /tmp path.
let artDir = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Caches/DMS/artwork", isDirectory: true)
try? FileManager.default.createDirectory(at: artDir, withIntermediateDirectories: true)
try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: artDir.path)
let artURL = artDir.appendingPathComponent("nowplaying_art.jpg")
var lastEmittedJSON = ""
var lastIsPlaying = false
let appNameLock = NSLock()

func finite(_ d: Double) -> Double { d.isFinite ? d : 0.0 }

func emitJSON(_ payload: [String: Any]) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: data, encoding: .utf8) else { return nil }
    return json
}

func emitState(force: Bool = false) {
    mrGetInfo(DispatchQueue.main) { info in
        guard let dict = info as? [String: Any],
              let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
              !title.isEmpty else {
            if let empty = emitJSON(["title": "", "artist": "", "album": "", "isPlaying": false, "duration": 0.0, "elapsed": 0.0, "rate": 0.0, "app": ""]) {
                if force || empty != lastEmittedJSON {
                    lastEmittedJSON = empty
                    lastIsPlaying = false
                    print(empty)
                    fflush(stdout)
                }
            }
            return
        }

        let artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        let album = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        let dur = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0.0
        let elapsed = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0
        let rate = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0

        // Handle artwork file write (atomic: unique temp + rename inside artDir)
        var hasArt = false
        if let artData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, !artData.isEmpty {
            let tmp = artDir.appendingPathComponent(".nowplaying_art.\(UUID().uuidString).tmp")
            if (try? artData.write(to: tmp)) != nil {
                try? FileManager.default.removeItem(at: artURL)
                try? FileManager.default.moveItem(at: tmp, to: artURL)
            }
            hasArt = true
        }

        var appName = "Media Player"
        if let getClient = mrGetClient {
            let sema = DispatchSemaphore(value: 0)
            getClient(DispatchQueue.global()) { client in
                var resolved = "Media Player"
                if let client = client {
                    if let getName = mrClientGetName, let n = getName(client) as String?, !n.isEmpty {
                        resolved = n
                    } else if let getBundle = mrClientGetBundle, let b = getBundle(client) as String?, !b.isEmpty {
                        resolved = b
                    }
                }
                // Guard against the timeout data race: the callback may signal after
                // the wait timed out, so every read/write of appName goes through the lock.
                appNameLock.lock()
                appName = resolved
                appNameLock.unlock()
                sema.signal()
            }
            _ = sema.wait(timeout: .now() + 0.1)
        }
        appNameLock.lock()
        let resolvedAppName = appName
        appNameLock.unlock()

        let isPlaying = rate > 0.0
        lastIsPlaying = isPlaying

        if let json = emitJSON([
            "title": title,
            "artist": artist,
            "album": album,
            "duration": finite(dur),
            "elapsed": finite(elapsed),
            "rate": finite(rate),
            "isPlaying": isPlaying,
            "hasArtwork": hasArt,
            "app": resolvedAppName
        ]) {
            if force || json != lastEmittedJSON {
                lastEmittedJSON = json
                print(json)
                fflush(stdout)
            }
        }
    }
}

// Check for one-shot CLI probe mode
if CommandLine.arguments.contains("--once") {
    emitState(force: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        exit(0)
    }
    dispatchMain()
}

// Register for system-wide MediaRemote events
mrReg(DispatchQueue.main)

let notifs = [
    "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
    "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
    "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
]
for n in notifs {
    NotificationCenter.default.addObserver(forName: NSNotification.Name(n), object: nil, queue: .main) { _ in
        emitState()
    }
}

// Periodic ticker when audio is actively playing
let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
timer.setEventHandler {
    if lastIsPlaying {
        emitState()
    }
}
timer.resume()

func handleCommand(_ trimmed: String) {
    if trimmed == "poll" {
        emitState(force: true)
    } else if trimmed == "play" {
        _ = mrSendCommand?(0, nil)
    } else if trimmed == "pause" {
        _ = mrSendCommand?(1, nil)
    } else if trimmed == "toggle" {
        _ = mrSendCommand?(2, nil)
    } else if trimmed == "next" {
        _ = mrSendCommand?(4, nil)
    } else if trimmed == "prev" {
        _ = mrSendCommand?(5, nil)
    } else if trimmed.starts(with: "seek ") {
        let secStr = String(trimmed.dropFirst(5))
        if let sec = Double(secStr) {
            mrSetElapsed?(sec)
        }
    } else if trimmed == "exit" || trimmed == "quit" {
        exit(0)
    }
}

// Standard input listener for commands; partial lines are buffered across reads
DispatchQueue.global(qos: .userInitiated).async {
    let stdinHandle = FileHandle.standardInput
    var stdinBuffer = ""
    while true {
        let data = stdinHandle.availableData
        if data.isEmpty {
            // Parent closed pipe -> terminate cleanly
            exit(0)
        }
        guard let chunk = String(data: data, encoding: .utf8) else { continue }
        stdinBuffer += chunk
        while let newlineIndex = stdinBuffer.firstIndex(of: "\n") {
            let cmd = String(stdinBuffer[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            stdinBuffer.removeSubrange(..<newlineIndex)
            if cmd.isEmpty { continue }
            DispatchQueue.main.async {
                handleCommand(cmd)
            }
        }
    }
}

// Emit initial state immediately
emitState()

dispatchMain()
