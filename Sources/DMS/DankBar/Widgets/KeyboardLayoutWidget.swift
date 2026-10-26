import SwiftUI
import AppKit
import Carbon.HIToolbox
import DMSCore

/// Manages keyboard layout state and Carbon input source cycling.
@MainActor
public final class KeyboardLayoutManager: ObservableObject {
    public static let shared = KeyboardLayoutManager()

    @Published public private(set) var currentLayoutCode: String = "US"
    @Published public private(set) var currentLayoutName: String = "U.S."

    private var observerRegistered = false

    private init() {
        refresh()
        registerObserver()
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDistributedCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(kTISNotifySelectedKeyboardInputSourceChanged),
            nil
        )
    }

    private func registerObserver() {
        guard !observerRegistered else { return }
        observerRegistered = true

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDistributedCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let manager = Unmanaged<KeyboardLayoutManager>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.refresh()
                }
            },
            kTISNotifySelectedKeyboardInputSourceChanged,
            nil,
            .deliverImmediately
        )
    }

    public func refresh() {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            currentLayoutCode = "US"
            currentLayoutName = "U.S."
            return
        }

        var name = "U.S."
        if let namePtr = TISGetInputSourceProperty(current, kTISPropertyLocalizedName) {
            name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        }

        var sourceID = ""
        if let idPtr = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) {
            sourceID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        }

        currentLayoutName = name
        currentLayoutCode = deriveShortCode(name: name, sourceID: sourceID)
    }

    public func cycleNextSource() {
        let properties: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsSelectCapable: true as Any
        ]

        guard let list = TISCreateInputSourceList(properties as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource],
              !list.isEmpty else { return }

        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }
        let currentID = TISGetInputSourceProperty(current, kTISPropertyInputSourceID).map {
            Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String
        } ?? ""

        let currentIndex = list.firstIndex { src in
            guard let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return false }
            let sid = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
            return sid == currentID
        } ?? 0

        let nextIndex = (currentIndex + 1) % list.count
        let nextSource = list[nextIndex]
        TISSelectInputSource(nextSource)

        refresh()
        ToastCenter.shared.show(icon: "keyboard", message: "Layout: \(currentLayoutName)")
    }

    private func deriveShortCode(name: String, sourceID: String) -> String {
        let lowerName = name.lowercased()
        let lowerID = sourceID.lowercased()

        if lowerID.contains("german") || lowerName.contains("german") || lowerName.contains("deutsch") {
            return "DE"
        } else if lowerID.contains("french") || lowerName.contains("français") || lowerName.contains("french") {
            return "FR"
        } else if lowerID.contains("japanese") || lowerName.contains("japanese") || lowerName.contains("日本語") {
            return "JP"
        } else if lowerID.contains("spanish") || lowerName.contains("español") || lowerName.contains("spanish") {
            return "ES"
        } else if lowerID.contains("russian") || lowerName.contains("русский") || lowerName.contains("russian") {
            return "RU"
        } else if lowerID.contains("italian") || lowerName.contains("italiano") {
            return "IT"
        } else if lowerID.contains("swedish") || lowerName.contains("svenska") {
            return "SE"
        } else if lowerID.contains("british") || lowerName.contains("british") {
            return "UK"
        } else if lowerName == "abc" {
            return "ABC"
        } else if lowerName.contains("dvorak") {
            return "DV"
        } else if lowerID.contains("us") || lowerName.contains("u.s.") || lowerName.contains("united states") {
            return "US"
        }

        // Generic fallback: first 2-3 uppercase characters
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 3 {
            return trimmed.uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }
}

/// Keyboard layout input source indicator with reactive update observer and click-to-cycle support.
/// Complies with `docs/spec/20-bar-widgets.md` `keyboardLayoutName`.
public struct KeyboardLayoutWidget: View {
    public var isVertical: Bool
    public var options: [String: AnyCodable]
    public var style: BarWidgetStyleOptions

    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var manager = KeyboardLayoutManager.shared

    public init(
        isVertical: Bool = false,
        options: [String: AnyCodable] = [:],
        style: BarWidgetStyleOptions = BarWidgetStyleOptions()
    ) {
        self.isVertical = isVertical
        self.options = options
        self.style = style
    }

    private var tintColor: Color {
        if let hex = style.customTintHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return theme.primary
    }

    private var backgroundColor: Color {
        if let hex = style.customBackgroundHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return theme.surfaceContainerHigh
    }

    public var body: some View {
        Button {
            manager.cycleNextSource()
        } label: {
            HStack(spacing: 4) {
                if style.showIcon {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(tintColor)
                }

                if !isVertical && style.showLabel {
                    Text(manager.currentLayoutCode)
                        .font(theme.font(size: 10, weight: .bold, mono: true))
                        .foregroundColor(theme.onSurface)
                }
            }
            .padding(.horizontal, isVertical ? 0 : 7)
            .frame(width: isVertical ? 28 : nil, height: isVertical ? 28 : 26)
            .background(backgroundColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Input Layout: \(manager.currentLayoutName) (Click to switch)")
    }
}
