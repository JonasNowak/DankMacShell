import SwiftUI
import AppKit
import Combine
import DMSCore

/// Lightweight in-process probe for a connected Nokia Belle / Symbian device (USB mass storage).
/// Scans mounted volumes with the shared `SymbianFilesystemHelper` detector — no companion process needed.
@MainActor
final class SymbianBarStatus: ObservableObject {
    static let shared = SymbianBarStatus()

    @Published private(set) var device: SymbianDevice? = nil

    private var timer: Timer?
    private var mountObserver: Any?
    private var unmountObserver: Any?

    private init() {
        start()
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scan() }
        }
        let center = NSWorkspace.shared.notificationCenter
        mountObserver = center.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scan() }
        }
        unmountObserver = center.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scan() }
        }
    }

    func scan() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsInternalKey]
        var found: SymbianDevice?
        if let volumes = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) {
            for volURL in volumes {
                if volURL.path == "/" || volURL.path == "/System/Volumes/Data" { continue }
                let name = (try? volURL.resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? volURL.lastPathComponent
                if let dev = SymbianFilesystemHelper.detectDevice(at: volURL, volumeName: name) {
                    found = dev
                    break
                }
            }
        }
        device = found
    }
}

/// Nokia Belle Sync bar pill for the DankBar (symbian plugin's own bar addition).
/// Shows the real Nokia C7 photo plus live connection state; clicking opens the dms-symbian companion.
/// Registered as the `symbianApplet` widget in `SettingsWidgetCatalog` and the `symbian` applet.
public struct SymbianBarWidget: View {
    public var isVertical: Bool
    public var options: [String: AnyCodable]
    public var style: BarWidgetStyleOptions

    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var status = SymbianBarStatus.shared

    public init(
        isVertical: Bool = false,
        options: [String: AnyCodable] = [:],
        style: BarWidgetStyleOptions = BarWidgetStyleOptions()
    ) {
        self.isVertical = isVertical
        self.options = options
        self.style = style
    }

    /// Bundled product photo of the Nokia C7 (CC BY-SA 3.0, see Resources/NokiaC7-Photo-Attribution.txt).
    private static var nokiaImage: NSImage? {
        Bundle.module.image(forResource: "nokia-c7.jpg")
    }

    private var tintColor: Color {
        if let hex = style.customTintHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return status.device != nil ? theme.primary : theme.onSurface
    }

    private var backgroundColor: Color {
        if let hex = style.customBackgroundHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return theme.barWidgetBackground
    }

    private var statusLabel: String {
        guard let dev = status.device else { return "No C7" }
        if style.compactMode || options["compactMode"]?.boolValue ?? false {
            return dev.driveLetter
        }
        return "\(dev.driveLetter) \(dev.formattedFreeSpace) free"
    }

    public var body: some View {
        Button {
            _ = SymbianClient.shared.launchCompanion()
        } label: {
            if isVertical {
                VStack(spacing: 2) {
                    deviceImage(size: 16)
                    Text(status.device?.driveLetter ?? "—")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(tintColor)
                        .lineLimit(1)
                }
                .frame(width: 28, height: 32)
                .background(backgroundColor)
                .clipShape(Capsule())
            } else {
                HStack(spacing: 5) {
                    deviceImage(size: 16)
                    if style.showLabel && !style.compactMode {
                        Text(statusLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(tintColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(.horizontal, style.compactMode ? 0 : 7)
                .frame(width: style.compactMode ? 28 : nil, height: 28)
                .background(backgroundColor)
            }
        }
        .buttonStyle(.plain)
        .help(status.device != nil
              ? "Nokia Belle Sync: \(status.device!.name) — \(status.device!.formattedFreeSpace) of \(status.device!.formattedTotalSpace) free. Click to open sync companion."
              : "Nokia Belle Sync: no Nokia C7 / Symbian device connected. Click to open sync companion.")
    }

    @ViewBuilder
    private func deviceImage(size: CGFloat) -> some View {
        if let img = Self.nokiaImage {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size / 4))
        } else if style.showIcon {
            Image(systemName: "phone.and.waveform")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tintColor)
        }
    }
}
