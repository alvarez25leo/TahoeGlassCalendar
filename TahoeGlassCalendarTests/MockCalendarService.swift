import Foundation
@testable import TahoeGlassCalendar

final class MockCalendarService: CalendarServiceProtocol, @unchecked Sendable {
    var status: CalendarPermissionState = .notDetermined
    var events: [CalendarEventItem] = []
    var requestAccessGranted: Bool = true

    private(set) var fetchCallCount = 0
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
}
