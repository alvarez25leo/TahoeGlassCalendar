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

    static let selectedDateLong: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = spanish
        formatter.dateFormat = "EEEE, d MMM"
        return formatter
    }()

    static func capitalizedMonthTitle(for date: Date) -> String {
        let raw = monthTitle.string(from: date)
        guard let first = raw.first else { return raw }
        return first.uppercased() + raw.dropFirst()
    }
}
