import Foundation

enum CalendarDateUtils {
    private static let dayIDFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dayIDLock = NSLock()

    static func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func monthRange(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = startOfMonth(for: date, calendar: calendar)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return (start, end)
    }

    /// 42-day rolling range used by the calendar grid (mes anterior + actual + siguiente, hasta 42 dias).
    static func gridRange(for date: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let startOfMonth = startOfMonth(for: date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -offset, to: startOfMonth) ?? startOfMonth
        let gridEnd = calendar.date(byAdding: .day, value: 42, to: gridStart) ?? gridStart
        return (gridStart, gridEnd)
    }

    static func dayID(for date: Date, calendar: Calendar = .current) -> String {
        dayIDLock.lock()
        defer { dayIDLock.unlock() }
        dayIDFormatter.calendar = calendar
        dayIDFormatter.timeZone = calendar.timeZone
        return dayIDFormatter.string(from: date)
    }

    static func mondayFirstCalendar(base: Calendar = .current) -> Calendar {
        var cal = base
        cal.firstWeekday = 2
        return cal
    }
}
