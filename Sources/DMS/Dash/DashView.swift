import SwiftUI
import DMSCore

/// Full Material 3 DankDash dashboard overlay view.
public struct DashView: View {
    @ObservedObject var themeStore = ThemeStore.shared
    let telemetry = TelemetryService.shared
    @ObservedObject var weather = WeatherService.shared
    @ObservedObject var nowPlaying = NowPlayingService.shared
    @ObservedObject var notepad = NotepadService.shared

    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        let p = themeStore.palette

        ZStack {
            // Scrim backdrop
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            // Dashboard card
            VStack(spacing: 24) {
                // Top Header Row
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greetingText)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: p.onSurface.hex))

                        Text(Date().formatted(date: .complete, time: .omitted))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                    }

                    Spacer()

                    // Close Button
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: p.surfaceVariant.hex).opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Main Grid: 2 Columns
                HStack(alignment: .top, spacing: 20) {
                    // Left Column: Weather & Media & Telemetry
                    VStack(spacing: 18) {
                        // Weather Card
                        HStack(spacing: 16) {
                            Image(systemName: weather.currentWeather.sfSymbol)
                                .font(.system(size: 38))
                                .foregroundColor(Color(hex: p.primary.hex))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Int(round(weather.currentWeather.temperatureC)))°C")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: p.onSurface.hex))

                                Text(weather.currentWeather.conditionDescription)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Label("\(weather.currentWeather.humidity)%", systemImage: "humidity.fill")
                                Label("\(Int(round(weather.currentWeather.windSpeedKmh))) km/h", systemImage: "wind")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: p.outline.hex))
                        }
                        .padding(18)
                        .background(Color(hex: p.surfaceContainerHigh.hex))
                        .cornerRadius(20)

                        // Media Player Card
                        VStack(spacing: 12) {
                            HStack(spacing: 14) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color(hex: p.primary.hex))
                                    .frame(width: 48, height: 48)
                                    .background(Color(hex: p.primaryContainer.hex))
                                    .cornerRadius(14)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(nowPlaying.currentTrack.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: p.onSurface.hex))
                                        .lineLimit(1)

                                    Text(nowPlaying.currentTrack.artist)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                                        .lineLimit(1)
                                }

                                Spacer()

                                HStack(spacing: 14) {
                                    Button(action: { nowPlaying.previous() }) {
                                        Image(systemName: "backward.fill")
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: { nowPlaying.playPause() }) {
                                        Image(systemName: nowPlaying.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 18))
                                            .frame(width: 36, height: 36)
                                            .background(Color(hex: p.primary.hex))
                                            .foregroundColor(Color(hex: p.onPrimary.hex))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: { nowPlaying.next() }) {
                                        Image(systemName: "forward.fill")
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .foregroundColor(Color(hex: p.onSurface.hex))
                            }

                            // Progress bar
                            ProgressView(value: nowPlaying.currentTrack.progress)
                                .accentColor(Color(hex: p.primary.hex))
                        }
                        .padding(18)
                        .background(Color(hex: p.surfaceContainerHigh.hex))
                        .cornerRadius(20)

                        // Hardware Telemetry Gauges
                        HStack(spacing: 14) {
                            TelemetryPill(
                                title: "CPU",
                                value: "\(Int(round(telemetry.telemetry.cpuPercent)))%",
                                icon: "cpu",
                                color: Color(hex: p.primary.hex),
                                bg: Color(hex: p.surfaceContainerHigh.hex),
                                fg: Color(hex: p.onSurface.hex)
                            )
                            TelemetryPill(
                                title: "RAM",
                                value: "\(Int(round(telemetry.telemetry.ramPercent)))%",
                                icon: "memorychip",
                                color: Color(hex: p.secondary.hex),
                                bg: Color(hex: p.surfaceContainerHigh.hex),
                                fg: Color(hex: p.onSurface.hex)
                            )
                            TelemetryPill(
                                title: "BATTERY",
                                value: "\(telemetry.telemetry.batteryPercent ?? 100)%",
                                icon: telemetry.telemetry.isCharging ? "bolt.batteryblock.fill" : "battery.100",
                                color: Color(hex: p.tertiary.hex),
                                bg: Color(hex: p.surfaceContainerHigh.hex),
                                fg: Color(hex: p.onSurface.hex)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Right Column: Calendar & Quick Scratchpad
                    VStack(spacing: 18) {
                        // Mini Month Calendar
                        CalendarCard(palette: p)

                        // Quick Scratchpad
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Quick Notes", systemImage: "note.text")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: p.onSurface.hex))
                                Spacer()
                                Text("\(notepad.activeNote.wordCount) words")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: p.outline.hex))
                            }

                            TextEditor(text: Binding(
                                get: { notepad.activeNote.content },
                                set: { notepad.updateActiveNote(content: $0) }
                            ))
                            .font(.system(size: 13, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(height: 100)
                        }
                        .padding(18)
                        .background(Color(hex: p.surfaceContainerHigh.hex))
                        .cornerRadius(20)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(28)
            .frame(width: 780, height: 500)
            .background(Color(hex: p.surface.hex).opacity(0.95))
            .cornerRadius(28)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color(hex: p.outlineVariant.hex).opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 30, x: 0, y: 15)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()
        if hour < 12 {
            return "Good morning, \(name)"
        } else if hour < 18 {
            return "Good afternoon, \(name)"
        } else {
            return "Good evening, \(name)"
        }
    }
}

private struct TelemetryPill: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let bg: Color
    let fg: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(fg)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(bg)
        .cornerRadius(18)
    }
}

private struct CalendarCard: View {
    let palette: DMSPalette

    var body: some View {
        let date = Date()
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let monthName = date.formatted(.dateTime.month(.wide).year())

        VStack(spacing: 10) {
            HStack {
                Text(monthName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: palette.onSurface.hex))
                Spacer()
                Text("Today: \(day)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: palette.primary.hex))
            }

            // Simple week grid header
            HStack {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { dayLabel in
                    Text(dayLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: palette.outline.hex))
                        .frame(maxWidth: .infinity)
                }
            }

            // Days display
            let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: date))!
            let range = cal.range(of: .day, in: .month, for: date)!
            let firstWeekday = cal.component(.weekday, from: startOfMonth) - 1

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(0..<max(0, firstWeekday - 1), id: \.self) { _ in
                    Text("").frame(width: 24, height: 24)
                }
                ForEach(1...range.count, id: \.self) { d in
                    Text("\(d)")
                        .font(.system(size: 12, weight: d == day ? .bold : .regular))
                        .frame(width: 26, height: 26)
                        .background(d == day ? Color(hex: palette.primary.hex) : Color.clear)
                        .foregroundColor(d == day ? Color(hex: palette.onPrimary.hex) : Color(hex: palette.onSurface.hex))
                        .clipShape(Circle())
                }
            }
        }
        .padding(18)
        .background(Color(hex: palette.surfaceContainerHigh.hex))
        .cornerRadius(20)
    }
}
