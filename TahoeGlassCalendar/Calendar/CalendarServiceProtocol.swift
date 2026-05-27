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

    /// Stream que emite cuando EventKit notifica que el store cambió (alguien
    /// editó eventos desde Calendar.app, iCloud sync, otra app, etc.). El
    /// ViewModel se suscribe acá para invalidar caches automáticamente.
    var eventStoreChanges: AsyncStream<Void> { get }
}
