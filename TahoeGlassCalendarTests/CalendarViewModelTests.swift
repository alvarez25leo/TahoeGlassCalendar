import XCTest
@testable import TahoeGlassCalendar

@MainActor
final class CalendarViewModelTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima") ?? TimeZone.current
        cal.firstWeekday = 2
        return cal
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9, minute: Int = 0) -> Date {
        let comps = DateComponents(
            calendar: calendar,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: comps)!
    }

    private func makeViewModel(
        mock: MockCalendarService = MockCalendarService()
    ) -> (CalendarViewModel, MockCalendarService) {
        let builder = CalendarMonthBuilder(calendar: calendar)
        let vm = CalendarViewModel(
            calendarService: mock,
            monthBuilder: builder,
            opener: AppleCalendarOpener()
        )
        return (vm, mock)
    }

    private func makeEvent(
        on date: Date,
        title: String = "Test",
        allDay: Bool = false,
        durationHours: Double = 1
    ) -> CalendarEventItem {
        CalendarEventItem(
            id: UUID().uuidString,
            title: title,
            startDate: date,
            endDate: date.addingTimeInterval(durationHours * 3600),
            isAllDay: allDay,
            calendarTitle: "Test Calendar",
            calendarColor: nil,
            location: nil,
            notes: nil,
            eventIdentifier: nil
        )
    }

    // MARK: - bootstrap

    func testBootstrapWithDeniedPermission() async {
        let (vm, mock) = makeViewModel()
        mock.status = .denied

        await vm.bootstrap()

        XCTAssertEqual(vm.permissionState, .denied)
        XCTAssertTrue(vm.days.isEmpty)
        XCTAssertFalse(vm.hasTodayEvents)
    }

    func testBootstrapWithFullAccessFetchesEvents() async {
        let (vm, mock) = makeViewModel()
        mock.status = .fullAccess
        mock.events = [makeEvent(on: date(2026, 5, 15))]
        vm.visibleMonth = date(2026, 5, 15)
        vm.selectedDate = date(2026, 5, 15)

        await vm.bootstrap()

        XCTAssertEqual(vm.permissionState, .fullAccess)
        XCTAssertEqual(vm.days.count, 42)
        XCTAssertGreaterThan(mock.fetchCallCount, 0)
    }

    func testBootstrapNotDeterminedDoesNotFetch() async {
        let (vm, mock) = makeViewModel()
        mock.status = .notDetermined

        await vm.bootstrap()

        XCTAssertEqual(vm.permissionState, .notDetermined)
        XCTAssertEqual(mock.fetchCallCount, 0)
    }

    // MARK: - requestAccess

    func testRequestAccessGrantedTriggersRefresh() async {
        let (vm, mock) = makeViewModel()
        mock.status = .notDetermined
        mock.requestAccessGranted = true
        vm.visibleMonth = date(2026, 5, 15)

        await vm.requestCalendarAccess()

        XCTAssertEqual(vm.permissionState, .fullAccess)
        XCTAssertEqual(vm.days.count, 42)
    }

    func testRequestAccessDeniedKeepsEmpty() async {
        let (vm, mock) = makeViewModel()
        mock.status = .notDetermined
        mock.requestAccessGranted = false

        await vm.requestCalendarAccess()

        XCTAssertNotEqual(vm.permissionState, .fullAccess)
        XCTAssertTrue(vm.days.isEmpty)
    }

    // MARK: - selectedDateEvents

    func testSelectedDateEventsFiltersByDay() async {
        let (vm, mock) = makeViewModel()
        mock.status = .fullAccess
        let target = date(2026, 5, 17, hour: 10)
        let other = date(2026, 5, 18, hour: 10)
        mock.events = [
            makeEvent(on: target, title: "Match"),
            makeEvent(on: other, title: "Miss")
        ]
        vm.visibleMonth = date(2026, 5, 1)
        vm.selectedDate = target

        await vm.bootstrap()

        XCTAssertEqual(vm.selectedDateEvents.count, 1)
        XCTAssertEqual(vm.selectedDateEvents.first?.title, "Match")
    }

    func testSelectedDateEventsAllDayBeforeTimed() async {
        let (vm, mock) = makeViewModel()
        mock.status = .fullAccess
        let day = date(2026, 5, 17, hour: 0)
        let allDay = makeEvent(on: day, title: "AllDay", allDay: true)
        let timed = makeEvent(on: date(2026, 5, 17, hour: 9), title: "Timed")
        mock.events = [timed, allDay]
        vm.visibleMonth = day
        vm.selectedDate = day

        await vm.bootstrap()

        XCTAssertEqual(vm.selectedDateEvents.first?.title, "AllDay")
        XCTAssertEqual(vm.selectedDateEvents.last?.title, "Timed")
    }

    // MARK: - month navigation

    func testGoToPreviousMonth() async {
        let (vm, mock) = makeViewModel()
        mock.status = .fullAccess
        vm.visibleMonth = date(2026, 5, 1)

        await vm.goToPreviousMonth()

        let comps = calendar.dateComponents([.year, .month], from: vm.visibleMonth)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 4)
    }

    func testGoToNextMonth() async {
        let (vm, mock) = makeViewModel()
        mock.status = .fullAccess
        vm.visibleMonth = date(2026, 5, 1)

        await vm.goToNextMonth()

        let comps = calendar.dateComponents([.year, .month], from: vm.visibleMonth)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 6)
    }

    func testGoToTodayResetsBoth() async {
        let (vm, mock) = makeViewModel()
        mock.status = .fullAccess
        vm.visibleMonth = date(2020, 1, 1)
        vm.selectedDate = date(2020, 1, 5)

        await vm.goToToday()

        XCTAssertTrue(calendar.isDateInToday(vm.selectedDate))
    }

    // MARK: - moveSelection

    func testMoveSelectionWithinMonth() async {
        let (vm, mock) = makeViewModel()
        mock.status = .fullAccess
        vm.visibleMonth = date(2026, 5, 1)
        vm.selectedDate = date(2026, 5, 10)

        await vm.moveSelection(by: 1)

        XCTAssertTrue(calendar.isDate(vm.selectedDate, inSameDayAs: date(2026, 5, 11)))
        let monthComps = calendar.dateComponents([.year, .month], from: vm.visibleMonth)
        XCTAssertEqual(monthComps.month, 5)
    }

    func testMoveSelectionCrossesMonth() async {
        let (vm, mock) = makeViewModel()
        mock.status = .fullAccess
        vm.visibleMonth = date(2026, 5, 1)
        vm.selectedDate = date(2026, 5, 31)

        await vm.moveSelection(by: 1)

        let comps = calendar.dateComponents([.year, .month, .day], from: vm.selectedDate)
        XCTAssertEqual(comps.month, 6)
        XCTAssertEqual(comps.day, 1)
        let monthComps = calendar.dateComponents([.year, .month], from: vm.visibleMonth)
        XCTAssertEqual(monthComps.month, 6)
    }

    // MARK: - grid range fix (bug #1)

    func testOverflowDayEventsAreReachable() async {
        let (vm, mock) = makeViewModel()
        mock.status = .fullAccess
        // Mes visible = mayo 2026, pero hay un evento en abril 30 (que cae como overflow en el grid).
        let overflow = date(2026, 4, 30, hour: 10)
        mock.events = [makeEvent(on: overflow, title: "Overflow")]
        vm.visibleMonth = date(2026, 5, 1)
        vm.selectedDate = overflow

        await vm.bootstrap()

        XCTAssertEqual(vm.selectedDateEvents.count, 1, "El evento de overflow debe ser visible")
        XCTAssertEqual(vm.selectedDateEvents.first?.title, "Overflow")
    }

    // MARK: - Multi-day events

    func testMultiDayEventVisibleOnMiddleDay() async {
        let (vm, mock) = makeViewModel()
        mock.status = .fullAccess
        // Evento del 27 al 29 (endDate exclusivo). Seleccionamos el 28.
        let start = date(2026, 5, 27, hour: 0)
        let end = date(2026, 5, 30, hour: 0)
        mock.events = [
            CalendarEventItem(
                id: "vac",
                title: "Vacaciones",
                startDate: start,
                endDate: end,
                isAllDay: true,
                calendarTitle: "Personal",
                calendarColor: nil,
                location: nil,
                notes: nil,
                eventIdentifier: "vac"
            )
        ]
        vm.visibleMonth = date(2026, 5, 1)
        vm.selectedDate = date(2026, 5, 28)

        await vm.bootstrap()

        XCTAssertEqual(vm.selectedDateEvents.count, 1, "El día 28 debería ver el evento que lo cubre")
        XCTAssertEqual(vm.selectedDateEvents.first?.title, "Vacaciones")
    }

    // MARK: - isViewingCurrentMonth

    func testIsViewingCurrentMonthTrue() async {
        let (vm, _) = makeViewModel()
        vm.visibleMonth = Date()
        XCTAssertTrue(vm.isViewingCurrentMonth)
    }

    func testIsViewingCurrentMonthFalse() async {
        let (vm, _) = makeViewModel()
        vm.visibleMonth = date(2020, 1, 1)
        XCTAssertFalse(vm.isViewingCurrentMonth)
    }
}
