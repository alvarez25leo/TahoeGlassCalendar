import EventKit
import Foundation
import os

final class CalendarService: CalendarServiceProtocol, @unchecked Sendable {
    private let store = EKEventStore()

    var eventStore: EKEventStore { store }

    func authorizationStatus() -> CalendarPermissionState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .fullAccess:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            AppLogger.calendar.error("Calendar permission error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Async: corre el predicate/fetch en un Task.detached para no bloquear el main actor.
    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEventItem] {
        let store = self.store
        return await Task.detached(priority: .userInitiated) {
            let predicate = store.predicateForEvents(
                withStart: startDate,
                end: endDate,
                calendars: nil
            )

            let items: [CalendarEventItem] = store.events(matching: predicate)
                .filter { $0.status != .canceled }
                .map { event in
                    let safeTitle: String
                    if let title = event.title, !title.isEmpty {
                        safeTitle = title
                    } else {
                        safeTitle = "Sin título"
                    }

                    return CalendarEventItem(
                        id: event.eventIdentifier ?? UUID().uuidString,
                        title: safeTitle,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        isAllDay: event.isAllDay,
                        calendarTitle: event.calendar.title,
                        calendarColor: event.calendar.cgColor,
                        location: event.location,
                        notes: event.notes,
                        eventIdentifier: event.eventIdentifier
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.isAllDay != rhs.isAllDay {
                        return lhs.isAllDay && !rhs.isAllDay
                    }
                    return lhs.startDate < rhs.startDate
                }

            return items
        }.value
    }
}
