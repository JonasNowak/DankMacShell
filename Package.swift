// swift-tools-version: 6.2
import PackageDescription

// DankMacShell (DMS) for macOS: Material Design 3 desktop shell
// (DankBar, DLauncherV2, Control Center, OSD, Power Menu).
// Event-driven native Swift architecture with dynamic wallpaper M3 theming.
let package = Package(
    name: "DMS",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "DankMacShell", targets: ["DMS"]),
        .executable(name: "dms", targets: ["DMSCLI"]),
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
        // Unit tests for core logic.
        .testTarget(name: "DMSCoreTests", dependencies: ["DMSCore"]),
    ]
)
