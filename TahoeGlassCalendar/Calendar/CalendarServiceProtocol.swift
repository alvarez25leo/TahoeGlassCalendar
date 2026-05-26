import Foundation

protocol CalendarServiceProtocol: AnyObject, Sendable {
    func authorizationStatus() -> CalendarPermissionState
    func requestAccess() async -> Bool
    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEventItem]
    func availableCalendars() -> [CalendarSource]
    func defaultCalendarID() -> String?
    func createEvent(_ draft: NewEventDraft) async throws -> String
    func updateEvent(eventID: String, draft: NewEventDraft) async throws
    func deleteEvent(eventID: String) async throws
}
