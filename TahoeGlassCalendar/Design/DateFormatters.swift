import Foundation

enum DateFormatters {
    private static let spanish = Locale(identifier: "es_ES")

    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = spanish
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static let eventTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = spanish
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let monthKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    static let selectedDateLong: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = spanish
        formatter.dateFormat = "EEEE, d MMM"
        return formatter
    }()

    /// Para VoiceOver: "lunes 26 de mayo de 2026".
    static let accessibleDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = spanish
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    /// Para grupos de búsqueda agrupados por día.
    static let searchGroupDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = spanish
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()

    static func capitalizedMonthTitle(for date: Date) -> String {
        let raw = monthTitle.string(from: date)
        guard let first = raw.first else { return raw }
        return first.uppercased() + raw.dropFirst()
    }
}
