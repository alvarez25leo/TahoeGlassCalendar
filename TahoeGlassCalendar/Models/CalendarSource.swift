import Foundation
import CoreGraphics

/// Calendario disponible para crear eventos (mapeo simple de EKCalendar).
struct CalendarSource: Identifiable, Hashable {
    let id: String
    let title: String
    let sourceTitle: String
    let color: CGColor?
    let allowsModifications: Bool

    static func == (lhs: CalendarSource, rhs: CalendarSource) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Payload para crear un evento desde el composer.
struct NewEventDraft: Equatable {
    var title: String
    var location: String
    var notes: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendarID: String

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && endDate >= startDate
    }
}
