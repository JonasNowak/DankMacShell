import SwiftUI
import DMSCore

/// Interactive month calendar card matching DankDash design.
public struct CalendarOverviewCard: View {
    @ObservedObject var themeStore = ThemeStore.shared
    @ObservedObject var calendarService = CalendarService.shared
    @State private var currentMonth: CalendarMonth
    @State private var selectedDate: Date = Date()

    public init(initialDate: Date = Date()) {
        let cal = Calendar.current
        let year = cal.component(.year, from: initialDate)
        let month = cal.component(.month, from: initialDate)
        _currentMonth = State(initialValue: CalendarMonth(year: year, month: month))
        _selectedDate = State(initialValue: initialDate)
    }

    public var body: some View {
        let p = themeStore.palette
        let activeKeys = calendarService.eventDateKeys.isEmpty
            ? calendarService.referenceDateKeys(for: currentMonth)
            : calendarService.eventDateKeys

        let days = CalendarEngine.generateMonthGrid(
            year: currentMonth.year,
            month: currentMonth.month,
            firstDayOfWeek: 0, // Sunday first, exactly matching screenshot
            selectedDate: selectedDate,
            eventDateKeys: activeKeys
        )

        VStack(spacing: 6) {
            // Month Navigation Header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonth = currentMonth.previousMonth()
                        calendarService.loadEvents(for: currentMonth)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(currentMonth.title)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: p.onSurface.hex))

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonth = currentMonth.nextMonth()
                        calendarService.loadEvents(for: currentMonth)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Day of Week Column Headers: Sun, Mon, Tue, Wed, Thu, Fri, Sat
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { dayHeader in
                    Text(dayHeader)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Color(hex: p.onSurfaceVariant.hex))
                        .frame(maxWidth: .infinity)
                }
            }

            // 6x7 Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(days) { day in
                    CalendarDayCell(
                        day: day,
                        palette: p,
                        onSelect: {
                            selectedDate = day.date
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: p.surfaceContainerHigh.hex))
        .cornerRadius(12)
        .onAppear {
            calendarService.loadEvents(for: currentMonth)
        }
    }
}

private struct CalendarDayCell: View {
    let day: CalendarDayItem
    let palette: DMSPalette
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 1) {
                Text("\(day.dayNumber)")
                    .font(.system(size: 9.0, weight: day.isSelected ? .bold : .regular))
                    .foregroundColor(textColor)
                    .frame(width: 20, height: 15)
                    .background(
                        ZStack {
                            if day.isSelected && day.isCurrentMonth {
                                Circle()
                                    .fill(Color(hex: palette.surfaceVariant.hex).opacity(0.8))
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: palette.primary.hex).opacity(0.6), lineWidth: 1)
                                    )
                            }
                        }
                    )

                // Event indicator bar / Selected underline
                if day.isSelected && day.isCurrentMonth {
                    Capsule()
                        .fill(Color(hex: palette.primary.hex))
                        .frame(width: 8.5, height: 1.5)
                } else if day.hasEvents {
                    Capsule()
                        .fill(day.isCurrentMonth ? Color(hex: palette.outline.hex).opacity(0.8) : Color(hex: palette.outline.hex).opacity(0.45))
                        .frame(width: 8.0, height: 1.2)
                } else {
                    Spacer()
                        .frame(height: 1.5)
                }
            }
            .frame(height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if !day.isCurrentMonth {
            return Color(hex: palette.outline.hex).opacity(0.4)
        } else if day.isSelected {
            return Color(hex: palette.primary.hex)
        } else {
            return Color(hex: palette.onSurface.hex)
        }
    }
}
