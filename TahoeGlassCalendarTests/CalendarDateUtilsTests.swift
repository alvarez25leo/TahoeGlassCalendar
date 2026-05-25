import XCTest
@testable import TahoeGlassCalendar

final class CalendarDateUtilsTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima") ?? TimeZone.current
        cal.firstWeekday = 2
        return cal
    }()

    func testStartOfMonth() {
        let comps = DateComponents(
            calendar: calendar,
            year: 2026,
            month: 5,
            day: 17,
            hour: 15,
            minute: 30
        )
        let date = calendar.date(from: comps)!

        let start = CalendarDateUtils.startOfMonth(for: date, calendar: calendar)
        let startComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)

        XCTAssertEqual(startComps.year, 2026)
        XCTAssertEqual(startComps.month, 5)
        XCTAssertEqual(startComps.day, 1)
        XCTAssertEqual(startComps.hour, 0)
        XCTAssertEqual(startComps.minute, 0)
    }

    func testMonthRangeSpansFullMonth() {
        let comps = DateComponents(calendar: calendar, year: 2026, month: 2, day: 10)
        let date = calendar.date(from: comps)!

        let range = CalendarDateUtils.monthRange(for: date, calendar: calendar)

        let startComps = calendar.dateComponents([.year, .month, .day], from: range.start)
        let endComps = calendar.dateComponents([.year, .month, .day], from: range.end)

        XCTAssertEqual(startComps.year, 2026)
        XCTAssertEqual(startComps.month, 2)
        XCTAssertEqual(startComps.day, 1)

        XCTAssertEqual(endComps.year, 2026)
        XCTAssertEqual(endComps.month, 3)
        XCTAssertEqual(endComps.day, 1)
    }

    func testDayIDIsStableYYYYMMDD() {
        let comps = DateComponents(
            calendar: calendar,
            year: 2026,
            month: 1,
            day: 9,
            hour: 23,
            minute: 59
        )
        let date = calendar.date(from: comps)!

        let id = CalendarDateUtils.dayID(for: date, calendar: calendar)
        XCTAssertEqual(id, "2026-01-09")
    }

    func testDayIDDoesNotCrossMidnightInSameZone() {
        let earlyComps = DateComponents(
            calendar: calendar,
            year: 2026,
            month: 3,
            day: 5,
            hour: 0,
            minute: 1
        )
        let lateComps = DateComponents(
            calendar: calendar,
            year: 2026,
            month: 3,
            day: 5,
            hour: 23,
            minute: 59
        )
        let early = calendar.date(from: earlyComps)!
        let late = calendar.date(from: lateComps)!

        XCTAssertEqual(
            CalendarDateUtils.dayID(for: early, calendar: calendar),
            CalendarDateUtils.dayID(for: late, calendar: calendar)
        )
    }
}
