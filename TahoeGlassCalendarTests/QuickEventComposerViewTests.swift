import XCTest
@testable import TahoeGlassCalendar

final class QuickEventComposerViewTests: XCTestCase {
    private func event(calendarTitle: String = "Personal", calendarID: String?) -> CalendarEventItem {
        let start = Date(timeIntervalSince1970: 1_778_688_000)
        return CalendarEventItem(
            id: "event-1",
            title: "Test",
            startDate: start,
            endDate: start.addingTimeInterval(3600),
            isAllDay: false,
            calendarTitle: calendarTitle,
            calendarID: calendarID,
            calendarColor: nil,
            location: nil,
            notes: nil,
            eventIdentifier: "event-1"
        )
    }

    func testResolvedCalendarIDPrefersExactCalendarIDWhenTitlesAreDuplicated() {
        let calendars = [
            CalendarSource(
                id: "icloud-personal",
                title: "Personal",
                sourceTitle: "iCloud",
                color: nil,
                allowsModifications: true
            ),
            CalendarSource(
                id: "google-personal",
                title: "Personal",
                sourceTitle: "Google",
                color: nil,
                allowsModifications: true
            )
        ]

        let resolved = QuickEventComposerView.resolvedCalendarID(
            for: event(calendarID: "google-personal"),
            calendars: calendars,
            defaultCalendarID: "icloud-personal"
        )

        XCTAssertEqual(resolved, "google-personal")
    }

    func testResolvedCalendarIDFallsBackToTitleForLegacyEventsWithoutCalendarID() {
        let calendars = [
            CalendarSource(
                id: "work",
                title: "Trabajo",
                sourceTitle: "iCloud",
                color: nil,
                allowsModifications: true
            )
        ]

        let resolved = QuickEventComposerView.resolvedCalendarID(
            for: event(calendarTitle: "Trabajo", calendarID: nil),
            calendars: calendars,
            defaultCalendarID: nil
        )

        XCTAssertEqual(resolved, "work")
    }
}
