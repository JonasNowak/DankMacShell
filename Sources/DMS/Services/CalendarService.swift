import Foundation
import AppKit
import EventKit
import DMSCore

/// Provides integration with macOS EventKit for calendar events.
@MainActor
public final class CalendarService: ObservableObject {
    public static let shared = CalendarService()

    @Published public private(set) var eventDateKeys: Set<String> = []
    @Published public private(set) var upcomingEvents: [EKEvent] = []
    @Published public private(set) var isAuthorized: Bool = false
    @Published public var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private let eventStore = EKEventStore()

    private init() {
        checkAuthorization()
    }

    public func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authorizationStatus = status
        if #available(macOS 14.0, *) {
            isAuthorized = (status == .fullAccess)
        } else {
            isAuthorized = (status == .authorized)
        }
    }

    public func requestAccess(completion: (@Sendable (Bool) -> Void)? = nil) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor [weak self] in
                    guard let self else {
                        completion?(granted)
                        return
                    }
                    self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    self.isAuthorized = granted
                    if granted {
                        self.loadEvents()
                    }
                    completion?(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                Task { @MainActor [weak self] in
                    guard let self else {
                        completion?(granted)
                        return
                    }
                    self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    self.isAuthorized = granted
                    if granted {
                        self.loadEvents()
                    }
                    completion?(granted)
                }
            }
        }
    }

    /// Opens System Settings at the Calendar privacy pane.
    public func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Loads events for the current month.
    public func loadEvents() {
        loadEvents(for: CalendarMonth())
    }

    /// Loads events for the given visible month
    public func loadEvents(for month: CalendarMonth) {
        checkAuthorization()
        guard isAuthorized else {
            // Unauthorized users never see fabricated event dots.
            eventDateKeys = []
            upcomingEvents = []
            return
        }

        let cal = Calendar(identifier: .gregorian)
        var comp = DateComponents()
        comp.year = month.year
        comp.month = month.month
        comp.day = 1
        comp.hour = 0
        comp.minute = 0
        guard let startOfMonth = cal.date(from: comp) else { return }

        // Load covering 7 days before and after
        let startDate = cal.date(byAdding: .day, value: -7, to: startOfMonth) ?? startOfMonth
        let endDate = cal.date(byAdding: .day, value: 42, to: startOfMonth) ?? startOfMonth

        let store = eventStore
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        // events(matching:) hits the calendar database — run it off the main actor.
        Task.detached { [weak self] in
            let events = store.events(matching: predicate)
            var keys: Set<String> = []
            for event in events {
                keys.insert(CalendarEngine.dateKey(from: event.startDate, calendar: cal))
            }
            let now = Date()
            let upcoming = events
                .filter { $0.endDate >= now }
                .sorted { $0.startDate < $1.startDate }
            Task { @MainActor [weak self] in
                guard let self, !Task.isCancelled else { return }
                // A legitimately empty month stays empty — no fabricated reference dots.
                self.eventDateKeys = keys
                self.upcomingEvents = upcoming
            }
        }
    }

    public func createEvent(title: String, startDate: Date, endDate: Date) -> Result<String, Error> {
        checkAuthorization()
        guard isAuthorized, let calendar = eventStore.defaultCalendarForNewEvents else {
            return .failure(NSError(
                domain: "DMS.CalendarService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Calendar access not authorized or no default calendar available"]
            ))
        }
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
            return .success(event.eventIdentifier ?? UUID().uuidString)
        } catch {
            return .failure(error)
        }
    }
}
