// swift-tools-version: 6.0
import PackageDescription

// DankMacShell (DMS) for macOS: Material Design 3 desktop shell
// (DankBar, DLauncherV2, Control Center, OSD, Power Menu).
// Event-driven native Swift architecture with dynamic wallpaper M3 theming.
let package = Package(
    name: "DMS",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DankMacShell", targets: ["DMS"]),
        .executable(name: "dms", targets: ["DMSCLI"]),
        .executable(name: "dms-symbian", targets: ["DMSSymbian"]),
    ],
    targets: [
        // Pure logic: M3 color tokens, dynamic theme generator, config, fuzzy app search, telemetry models, IPC, clipboard, notepad, weather.
        .target(name: "DMSCore"),
        // Native macOS application: AppKit NSPanels, SwiftUI views, system event services, Unix socket server.
        .executableTarget(
            name: "DMS",
            dependencies: ["DMSCore"],
            resources: [
                .process("Resources")
            ]
        ),
        // Native dms CLI binary for terminal and keybind integration (dms run, dms ipc call ..., dms doctor, etc.).
        .executableTarget(name: "DMSCLI", dependencies: ["DMSCore"], path: "Sources/DMSCLI"),
        // Standalone Nokia Belle USB Sync companion application (crash-isolated companion process like danksearch).
        .executableTarget(
            name: "DMSSymbian",
            dependencies: ["DMSCore"],
            path: "Sources/DMSSymbian",
            resources: [
                .process("Resources")
            ]
        ),
        // Unit tests for core logic.
        .testTarget(name: "DMSCoreTests", dependencies: ["DMSCore"]),
    ],
    swiftLanguageModes: [.v5]
)
