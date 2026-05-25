import Foundation
import CoreGraphics

struct CalendarDayItem: Identifiable, Equatable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isToday: Bool
    let isSelected: Bool
    let isCurrentMonth: Bool
    let isWeekend: Bool
    let hasEvents: Bool
    let eventColors: [CGColor]

    static func == (lhs: CalendarDayItem, rhs: CalendarDayItem) -> Bool {
        lhs.id == rhs.id
            && lhs.isToday == rhs.isToday
            && lhs.isSelected == rhs.isSelected
            && lhs.isCurrentMonth == rhs.isCurrentMonth
            && lhs.isWeekend == rhs.isWeekend
            && lhs.hasEvents == rhs.hasEvents
            && lhs.eventColors.count == rhs.eventColors.count
    }
}
