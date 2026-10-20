import SwiftUI
import AppKit
import Collaboration
import Combine
import DMSCore

/// User and system host card with avatar, username, host details, and system uptime.
public struct UserInfoCard: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @State private var uptimeString: String = ""
    @State private var userAvatar: NSImage?

    private let timer = Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        let p = themeStore.palette
        let userName = NSUserName()

        HStack(spacing: 10) {
            // Circular Avatar with distinct white border matching screenshot
            ZStack {
                if let avatar = userAvatar {
                    Image(nsImage: avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: p.primaryContainer.hex), Color(hex: p.surfaceVariant.hex)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)

                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(Color(hex: p.primary.hex))
                }

                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(userName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: p.onSurface.hex))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(Color(hex: p.primary.hex))

                    Text("on macOS")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: p.primary.hex))

                    Text(uptimeString.isEmpty ? "up 16 hours, 22 minutes" : uptimeString)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: p.surfaceContainerHigh.hex))
        .cornerRadius(12)


        .onAppear {
            updateUptime()
            loadAvatar()
        }
        .onReceive(timer) { _ in
            updateUptime()
        }
    }

    private func updateUptime() {
        let seconds = ProcessInfo.processInfo.systemUptime
        uptimeString = UptimeFormatter.format(seconds: seconds)
    }

    private func loadAvatar() {
        if let identity = CBIdentity(name: NSUserName(), authority: CBIdentityAuthority.default()) {
            self.userAvatar = identity.image
        }
    }
}
