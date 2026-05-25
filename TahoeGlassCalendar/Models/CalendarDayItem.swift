import Foundation

struct CalendarDayItem: Identifiable, Equatable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isToday: Bool
    let isSelected: Bool
    let isCurrentMonth: Bool
    let hasEvents: Bool
}
