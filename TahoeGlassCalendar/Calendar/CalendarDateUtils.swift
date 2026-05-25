import Foundation

enum CalendarDateUtils {
    static func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func monthRange(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = startOfMonth(for: date, calendar: calendar)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return (start, end)
    }

    static func dayID(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func mondayFirstCalendar(base: Calendar = .current) -> Calendar {
        var cal = base
        cal.firstWeekday = 2
        return cal
    }
}
