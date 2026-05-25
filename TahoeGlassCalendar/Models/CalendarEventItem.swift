import Foundation
import CoreGraphics

struct CalendarEventItem: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let calendarColor: CGColor?
    let location: String?
    let notes: String?
    let eventIdentifier: String?

    static func == (lhs: CalendarEventItem, rhs: CalendarEventItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.startDate == rhs.startDate &&
        lhs.endDate == rhs.endDate &&
        lhs.isAllDay == rhs.isAllDay &&
        lhs.calendarTitle == rhs.calendarTitle &&
        lhs.location == rhs.location &&
        lhs.notes == rhs.notes &&
        lhs.eventIdentifier == rhs.eventIdentifier
    }
}
