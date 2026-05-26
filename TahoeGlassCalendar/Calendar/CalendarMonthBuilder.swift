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

        // Para cada evento, listamos TODOS los dias que cubre (multi-day support).
        // hasta 3 colores únicos por día.
        var colorsByDay: [String: [CGColor]] = [:]
        let fallbackColor = CGColor(red: 0, green: 0.48, blue: 1, alpha: 1)

        for event in events {
            let color = event.calendarColor ?? fallbackColor

            // Determinamos el rango de dias que ocupa el evento.
            let firstDay = calendar.startOfDay(for: event.startDate)
            let lastBoundary = event.endDate

            // Si endDate == startDate (instantáneo) o el evento termina antes del
            // siguiente startOfDay, ocupa solo un día.
            var current = firstDay
            var iterations = 0
            let safety = 366 // por si acaso

            while current < lastBoundary && iterations < safety {
                let id = CalendarDateUtils.dayID(for: current, calendar: calendar)
                var existing = colorsByDay[id] ?? []
                if existing.count < 3 && !existing.contains(where: { areCGColorsEqual($0, color) }) {
                    existing.append(color)
                }
                colorsByDay[id] = existing

                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
                iterations += 1
            }

            // Edge case: evento de duracion cero (start == end). Lo marcamos en su día.
            if event.startDate == event.endDate {
                let id = CalendarDateUtils.dayID(for: event.startDate, calendar: calendar)
                var existing = colorsByDay[id] ?? []
                if existing.count < 3 && !existing.contains(where: { areCGColorsEqual($0, color) }) {
                    existing.append(color)
                }
                colorsByDay[id] = existing
            }
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
            let isWeekend = (weekday == 1 || weekday == 7)

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
