// swift-tools-version: 6.2
import PackageDescription

// DankMaterialShell (DMS) for macOS: Material Design 3 desktop shell
// (DankBar, DLauncherV2, Control Center, OSD, Power Menu).
// Event-driven native Swift architecture with dynamic wallpaper M3 theming.
let package = Package(
    name: "DMS",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "DMS", targets: ["DMS"]),
    ],
    targets: [
        // Pure logic: M3 color tokens, dynamic theme generator, config, fuzzy app search, telemetry models, IPC.
        .target(name: "DMSCore"),
        // Native macOS application: AppKit NSPanels, SwiftUI views, system event services.
        .executableTarget(name: "DMS", dependencies: ["DMSCore"]),
        // Unit tests for core logic.
        .testTarget(name: "DMSCoreTests", dependencies: ["DMSCore"]),
    ]
)
