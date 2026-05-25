import Foundation

protocol CalendarServiceProtocol: AnyObject, Sendable {
    func authorizationStatus() -> CalendarPermissionState
    func requestAccess() async -> Bool
    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEventItem]
}
