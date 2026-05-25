import Foundation

final class CalendarMonthBuilder {
    let calendar: Calendar

    init(calendar: Calendar = CalendarDateUtils.mondayFirstCalendar()) {
        self.calendar = calendar
    }

    func buildDays(
        visibleMonth: Date,
        selectedDate: Date,
        events: [CalendarEventItem]
    ) -> [CalendarDayItem] {
        let startOfMonth = CalendarDateUtils.startOfMonth(for: visibleMonth, calendar: calendar)

        let weekday = calendar.component(.weekday, from: startOfMonth)
        let offset = (weekday - calendar.firstWeekday + 7) % 7

        guard let gridStart = calendar.date(byAdding: .day, value: -offset, to: startOfMonth) else {
            return []
        }

        let eventDays: Set<String> = Set(
            events.map { CalendarDateUtils.dayID(for: $0.startDate, calendar: calendar) }
        )

        return (0..<42).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: gridStart) else {
                return nil
            }

            let dayNumber = calendar.component(.day, from: date)
            let sameMonth = calendar.isDate(date, equalTo: startOfMonth, toGranularity: .month)
            let isToday = calendar.isDateInToday(date)
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let dayID = CalendarDateUtils.dayID(for: date, calendar: calendar)
            let hasEvents = eventDays.contains(dayID)

            return CalendarDayItem(
                id: dayID,
                date: date,
                dayNumber: dayNumber,
                isToday: isToday,
                isSelected: isSelected,
                isCurrentMonth: sameMonth,
                hasEvents: hasEvents
            )
        }
    }
}
