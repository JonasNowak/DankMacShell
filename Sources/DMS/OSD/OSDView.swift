import SwiftUI
import AppKit
import DMSCore
import MaterialMacLibrary

/// On-screen display pill. The pill chrome (frosted glass capsule, gauge track, readout,
/// border, shadow) is delegated to `MaterialComponents.MaterialOSDPill` with the bridged
/// `MaterialTheme`; `OSDType` icon/value resolution stays in DMSCore.
public struct OSDView: View {
    @ObservedObject private var theme = ThemeStore.shared
    public let type: OSDType
    public let value: Double?
    public let isMuted: Bool
    public let text: String?

    public init(type: OSDType, value: Double? = nil, isMuted: Bool = false, text: String? = nil) {
        self.type = type
        self.value = value
        self.isMuted = isMuted
        self.text = text
    }

    public var body: some View {
        MaterialOSDPill(
            icon: type.iconName(isMuted: isMuted, value: value, text: text),
            value: type.isGaugeMetric ? value : nil,
            title: type.isGaugeMetric ? "" : type.title,
            formattedValue: type.formattedValue(isMuted: isMuted, value: value, text: text),
            width: 260,
            blurEnabled: true
        )
        .materialTheme(theme.materialTheme)
    }
}
