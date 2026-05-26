import XCTest
@testable import TahoeGlassCalendar

final class CalendarMonthBuilderTests: XCTestCase {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima") ?? TimeZone.current
        cal.firstWeekday = 2
        return cal
    }()

    private func makeBuilder() -> CalendarMonthBuilder {
        CalendarMonthBuilder(calendar: calendar)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        let comps = DateComponents(
            calendar: calendar,
            year: year,
            month: month,
            day: day,
            hour: hour
        )
        return calendar.date(from: comps)!
    }

    func testAlwaysProduces42Days() {
        let builder = makeBuilder()
        let visible = date(2026, 5, 1)
        let days = builder.buildDays(visibleMonth: visible, selectedDate: visible, events: [])
        XCTAssertEqual(days.count, 42)
    }

    func testFebruaryLeapYear2024() {
        let builder = makeBuilder()
        let visible = date(2024, 2, 1)
        let days = builder.buildDays(visibleMonth: visible, selectedDate: visible, events: [])

        let februaryDays = days.filter { $0.isCurrentMonth }
        XCTAssertEqual(februaryDays.count, 29)
    }

    func testFebruaryNonLeapYear2026() {
        let builder = makeBuilder()
        let visible = date(2026, 2, 1)
        let days = builder.buildDays(visibleMonth: visible, selectedDate: visible, events: [])

        let februaryDays = days.filter { $0.isCurrentMonth }
        XCTAssertEqual(februaryDays.count, 28)
    }

    func testMarksSelectedDate() {
        let builder = makeBuilder()
        let visible = date(2026, 5, 1)
        let selected = date(2026, 5, 17)

        let days = builder.buildDays(visibleMonth: visible, selectedDate: selected, events: [])

        let selectedDays = days.filter { $0.isSelected }
        XCTAssertEqual(selectedDays.count, 1)
        XCTAssertEqual(selectedDays.first?.dayNumber, 17)
        XCTAssertTrue(selectedDays.first?.isCurrentMonth ?? false)
    }

    func testMarksHasEventsCorrectly() {
        let builder = makeBuilder()
        let visible = date(2026, 5, 1)
        let eventDate = date(2026, 5, 10)

        let event = CalendarEventItem(
            id: "test-1",
            title: "Reunión",
            startDate: eventDate,
            endDate: eventDate.addingTimeInterval(3600),
            isAllDay: false,
            calendarTitle: "Work",
            calendarColor: nil,
            location: nil,
            notes: nil,
            eventIdentifier: "test-1"
        )

        let days = builder.buildDays(
            visibleMonth: visible,
            selectedDate: visible,
            events: [event]
        )

        let withEvents = days.filter { $0.hasEvents }
        XCTAssertEqual(withEvents.count, 1)
        XCTAssertEqual(withEvents.first?.dayNumber, 10)
    }

    func testMonthStartingMondayHasZeroOffset() {
        let builder = makeBuilder()
        let visible = date(2026, 6, 1)

        let days = builder.buildDays(visibleMonth: visible, selectedDate: visible, events: [])

        XCTAssertTrue(days.first?.isCurrentMonth ?? false)
        XCTAssertEqual(days.first?.dayNumber, 1)
    }

    func testMultiDayEventMarksAllCoveredDays() {
        let builder = makeBuilder()
        let visible = date(2026, 5, 1)
        // Evento de 3 días: 27, 28, 29 de mayo 2026
        let start = date(2026, 5, 27, hour: 0)
        let end = date(2026, 5, 30, hour: 0)  // endDate exclusivo (típico de all-day)

        let event = CalendarEventItem(
            id: "multi",
            title: "Vacaciones",
            startDate: start,
            endDate: end,
            isAllDay: true,
            calendarTitle: "Personal",
            calendarColor: nil,
            location: nil,
            notes: nil,
            eventIdentifier: "multi"
        )

        let days = builder.buildDays(visibleMonth: visible, selectedDate: visible, events: [event])

        let markedDays = days.filter { $0.hasEvents }.map { $0.dayNumber }
        XCTAssertTrue(markedDays.contains(27), "Día 27 debe estar marcado")
        XCTAssertTrue(markedDays.contains(28), "Día 28 debe estar marcado")
        XCTAssertTrue(markedDays.contains(29), "Día 29 debe estar marcado")
        XCTAssertFalse(markedDays.contains(30), "Día 30 NO debe estar marcado (endDate exclusivo)")
    }

    func testMonthStartingSundayHasSixOffset() {
        let builder = makeBuilder()
        let visible = date(2026, 3, 1)

        let days = builder.buildDays(visibleMonth: visible, selectedDate: visible, events: [])

        XCTAssertFalse(days[0].isCurrentMonth)
        XCTAssertFalse(days[5].isCurrentMonth)
        XCTAssertTrue(days[6].isCurrentMonth)
        XCTAssertEqual(days[6].dayNumber, 1)
    }
}
