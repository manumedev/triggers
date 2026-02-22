import Foundation
import EventKit
import OSLog

private let logger = Logger(subsystem: "com.remindme.app", category: "CalendarService")

@MainActor
final class CalendarService: ObservableObject {

    static let shared = CalendarService()

    private let store = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined

    /// Fires with (event title, minutesBefore)
    var onUpcomingEvent: ((String) -> Void)?

    private var checkTimer: Timer?

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            logger.info("Calendar access granted: \(granted)")
            return granted
        } catch {
            logger.error("Calendar authorization error: \(error)")
            return false
        }
    }

    // MARK: - Polling

    /// Starts a timer that checks for upcoming events every minute.
    func startPolling(interval: TimeInterval = 60) {
        stopPolling()
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkUpcomingEvents() }
        }
        checkUpcomingEvents()
    }

    func stopPolling() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Event lookup

    private func checkUpcomingEvents() {
        guard authorizationStatus == .fullAccess else { return }
        let now = Date()
        let lookAhead: TimeInterval = 60 * 60  // Check events in the next 60 minutes
        let end = now.addingTimeInterval(lookAhead)

        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        for event in events {
            onUpcomingEvent?(event.title ?? "")
        }
    }

    /// Returns the number of minutes until `event` starts (from now).
    func minutesUntil(event: EKEvent) -> Int {
        Int(event.startDate.timeIntervalSinceNow / 60)
    }

    /// Fetches upcoming events within the next `hours` hours.
    func upcomingEvents(withinHours hours: Double = 2) -> [EKEvent] {
        guard authorizationStatus == .fullAccess else { return [] }
        let now = Date()
        let end = now.addingTimeInterval(hours * 3600)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        return store.events(matching: predicate)
    }
}
