import AppKit
import Foundation
import DMSCore

@MainActor
final class SymbianAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        SymbianSyncWindowController.shared.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

func printCLIHelp() {
    print("""
    Nokia Belle USB Sync Companion (dms-symbian)
    Usage:
      dms-symbian                     Launch full companion GUI
      dms-symbian --gui               Launch full companion GUI
      dms-symbian status              Show connected Nokia Belle / Symbian devices
      dms-symbian sync                Perform MP3 music sync to active device
      dms-symbian clean               Clean hidden macOS AppleDouble (._*) dotfiles
      dms-symbian install <file>      Stage .sisx/.sis/.jar package to Installs directory
      dms-symbian eject               Safely eject active Symbian device
      dms-symbian --help, -h          Show this help message
    """)
}

@MainActor
func runCLI() async {
    let args = Array(CommandLine.arguments.dropFirst())
    let command = args.first?.lowercased() ?? "--gui"

    switch command {
    case "--help", "-h":
        printCLIHelp()
        exit(0)

    case "status":
        SymbianSyncService.shared.scanMountedVolumes()
        let devs = SymbianSyncService.shared.connectedDevices
        if devs.isEmpty {
            print("Nokia Belle Sync: No Nokia C7 or Symbian device connected.")
            print("Tip: Connect your phone via USB Mass Storage mode.")
        } else {
            print("Connected Symbian Devices (\(devs.count)):")
            for d in devs {
                let activeMarker = (d.id == SymbianSyncService.shared.activeDevice?.id) ? " [Active]" : ""
                print(" - \(d.name)\(activeMarker):")
                print("     Mount: \(d.mountPath)")
                print("     Capacity: \(d.formattedFreeSpace) free of \(d.formattedTotalSpace)")
                print("     OS: \(d.osVersion)")
            }
        }
        exit(0)

    case "clean":
        SymbianSyncService.shared.scanMountedVolumes()
        guard let dev = SymbianSyncService.shared.activeDevice else {
            print("Error: No Symbian device connected to clean.")
            exit(1)
        }
        let mountURL = URL(fileURLWithPath: dev.mountPath)
        let cleaned = SymbianFilesystemHelper.cleanAppleDoubleFiles(at: mountURL)
        print("Successfully cleaned \(cleaned) macOS AppleDouble (._*) dotfiles from \(dev.name).")
        exit(0)

    case "eject":
        SymbianSyncService.shared.scanMountedVolumes()
        guard let dev = SymbianSyncService.shared.activeDevice else {
            print("Error: No active device to eject.")
            exit(1)
        }
        SymbianSyncService.shared.ejectActiveDevice()
        print("Ejected \(dev.name).")
        exit(0)

    case "install":
        guard args.count >= 2 else {
            print("Error: 'install' requires path to .sis, .sisx, or .jar package.")
            exit(1)
        }
        let filePath = args[1]
        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Error: File not found at '\(filePath)'.")
            exit(1)
        }

        SymbianSyncService.shared.scanMountedVolumes()
        guard SymbianSyncService.shared.activeDevice != nil else {
            print("Error: No Symbian device connected. Connect your Nokia C7 via USB Mass Storage mode.")
            exit(1)
        }

        do {
            let pkg = try await SymbianSyncService.shared.stagePackage(from: url)
            let drive = SymbianSyncService.shared.activeDevice?.driveLetter ?? "E:"
            print("Successfully staged '\(pkg.appName)' (\(pkg.version)) to Drive \(drive)\\Installs.")
            print("Open File Manager on your phone to complete installation.")
            exit(0)
        } catch {
            print("Error staging package: \(error.localizedDescription)")
            exit(1)
        }

    case "sync":
        SymbianSyncService.shared.scanMountedVolumes()
        guard SymbianSyncService.shared.activeDevice != nil else {
            print("Error: No Symbian device connected. Connect your Nokia C7 via USB Mass Storage mode.")
            exit(1)
        }
        SymbianSyncService.shared.scanLocalMusic()

        // Wait briefly for local scan to discover tracks
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if !SymbianSyncService.shared.isScanningLocal { break }
        }

        let tracks = SymbianSyncService.shared.localTracks
        print("Found \(tracks.count) tracks in local library. Starting sync...")

        if tracks.isEmpty {
            print("No local audio files found in ~/Music to sync.")
            exit(0)
        }

        let synced = await SymbianSyncService.shared.syncTracks(tracks: tracks)
        print("Sync complete! Successfully transferred \(synced) tracks to Nokia C7.")
        exit(0)

    default:
        print("Unknown command: '\(command)'. Run 'dms-symbian --help' for usage.")
        exit(1)
    }
}

// Entry Point
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty || arguments.contains("--gui") {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = SymbianAppDelegate()
        app.delegate = delegate
        app.run()
    }
} else {
    Task { @MainActor in
        await runCLI()
    }
    RunLoop.main.run()
}
