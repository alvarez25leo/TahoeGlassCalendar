import Foundation
import CoreGraphics
@testable import TahoeGlassCalendar

final class MockCalendarService: CalendarServiceProtocol, @unchecked Sendable {
    var status: CalendarPermissionState = .notDetermined
    var events: [CalendarEventItem] = []
    var requestAccessGranted: Bool = true
    var calendars: [CalendarSource] = [
        CalendarSource(
            id: "default-cal",
            title: "Personal",
            sourceTitle: "iCloud",
            color: CGColor(red: 0, green: 0.48, blue: 1, alpha: 1),
            allowsModifications: true
        )
    ]
    var defaultID: String? = "default-cal"

    private(set) var fetchCallCount = 0
    private(set) var createdEvents: [NewEventDraft] = []
    private(set) var updatedEvents: [(String, NewEventDraft)] = []
    private(set) var deletedEventIDs: [String] = []
    private(set) var lastFetchRange: (Date, Date)?

    func authorizationStatus() -> CalendarPermissionState {
        status
    }

    func requestAccess() async -> Bool {
        if requestAccessGranted {
            status = .fullAccess
        } else {
            status = .denied
        }
        return requestAccessGranted
    }

    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEventItem] {
        fetchCallCount += 1
        lastFetchRange = (startDate, endDate)
        return events.filter { $0.startDate >= startDate && $0.startDate < endDate }
    }

    func availableCalendars() -> [CalendarSource] {
        calendars
    }

    func defaultCalendarID() -> String? {
        defaultID
    }

    func createEvent(_ draft: NewEventDraft) async throws -> String {
        createdEvents.append(draft)
        return UUID().uuidString
    }

    func updateEvent(eventID: String, draft: NewEventDraft) async throws {
        updatedEvents.append((eventID, draft))
    }

    func deleteEvent(eventID: String) async throws {
        deletedEventIDs.append(eventID)
    }
}
