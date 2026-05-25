import Foundation
import CoreGraphics

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
        let gridRange = CalendarDateUtils.gridRange(for: visibleMonth, calendar: calendar)
        let gridStart = gridRange.start

        // Index eventos por dayID: para cada día listamos colores únicos (hasta 3).
        var colorsByDay: [String: [CGColor]] = [:]
        for event in events {
            let id = CalendarDateUtils.dayID(for: event.startDate, calendar: calendar)
            var existing = colorsByDay[id] ?? []
            if let color = event.calendarColor {
                if existing.count < 3 && !existing.contains(where: { areCGColorsEqual($0, color) }) {
                    existing.append(color)
                }
            } else if existing.isEmpty {
                existing.append(CGColor(red: 0, green: 0.48, blue: 1, alpha: 1)) // fallback accent
            }
            colorsByDay[id] = existing
        }

        return (0..<42).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: gridStart) else {
                return nil
            }

            let dayNumber = calendar.component(.day, from: date)
            let sameMonth = calendar.isDate(date, equalTo: startOfMonth, toGranularity: .month)
            let isToday = calendar.isDateInToday(date)
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let dayID = CalendarDateUtils.dayID(for: date, calendar: calendar)
            let colors = colorsByDay[dayID] ?? []
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = (weekday == 1 || weekday == 7) // Sun = 1, Sat = 7

            return CalendarDayItem(
                id: dayID,
                date: date,
                dayNumber: dayNumber,
                isToday: isToday,
                isSelected: isSelected,
                isCurrentMonth: sameMonth,
                isWeekend: isWeekend,
                hasEvents: !colors.isEmpty,
                eventColors: colors
            )
        }
    }

    private func areCGColorsEqual(_ a: CGColor, _ b: CGColor) -> Bool {
        guard let ac = a.components, let bc = b.components, ac.count == bc.count else { return false }
        for i in 0..<ac.count where abs(ac[i] - bc[i]) > 0.001 { return false }
        return true
    }
}
