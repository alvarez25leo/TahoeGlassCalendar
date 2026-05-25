import Foundation
import Combine

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published private(set) var permissionState: CalendarPermissionState = .notDetermined
    @Published var visibleMonth: Date = Date()
    @Published var selectedDate: Date = Date()

    @Published private(set) var days: [CalendarDayItem] = []
    @Published private(set) var selectedDateEvents: [CalendarEventItem] = []
    @Published private(set) var todayEventCount: Int = 0
    @Published private(set) var hasTodayEvents: Bool = false
    @Published private(set) var isLoading: Bool = false

    private let calendarService: CalendarService
    private let monthBuilder: CalendarMonthBuilder
    private let opener: AppleCalendarOpener
    private let workCalendar: Calendar

    private var monthEvents: [CalendarEventItem] = []

    init(
        calendarService: CalendarService = CalendarService(),
        monthBuilder: CalendarMonthBuilder = CalendarMonthBuilder(),
        opener: AppleCalendarOpener = AppleCalendarOpener()
    ) {
        self.calendarService = calendarService
        self.monthBuilder = monthBuilder
        self.opener = opener
        self.workCalendar = monthBuilder.calendar
    }

    func bootstrap() async {
        permissionState = calendarService.authorizationStatus()

        if permissionState == .notDetermined {
            return
        }

        if permissionState == .fullAccess {
            await refresh()
        }
    }

    func requestCalendarAccess() async {
        let granted = await calendarService.requestAccess()
        permissionState = granted ? .fullAccess : calendarService.authorizationStatus()

        if granted {
            await refresh()
        }
    }

    func refresh() async {
        guard permissionState == .fullAccess else {
            rebuildTodayIndicator()
            return
        }

        isLoading = true
        defer { isLoading = false }

        let monthRange = CalendarDateUtils.monthRange(for: visibleMonth, calendar: workCalendar)
        monthEvents = calendarService.fetchEvents(
            from: monthRange.start,
            to: monthRange.end
        )

        rebuildDays()
        rebuildSelectedDateEvents()
        rebuildTodayIndicator()
    }

    func goToPreviousMonth() async {
        if let newMonth = workCalendar.date(byAdding: .month, value: -1, to: visibleMonth) {
            visibleMonth = newMonth
        }
        await refresh()
    }

    func goToNextMonth() async {
        if let newMonth = workCalendar.date(byAdding: .month, value: 1, to: visibleMonth) {
            visibleMonth = newMonth
        }
        await refresh()
    }

    func goToToday() async {
        visibleMonth = Date()
        selectedDate = Date()
        await refresh()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        rebuildDays()
        rebuildSelectedDateEvents()
    }

    func openCalendar() {
        opener.openCalendarApp()
    }

    func openEvent(_ event: CalendarEventItem) {
        _ = event
        opener.openCalendarApp()
    }

    private func rebuildDays() {
        days = monthBuilder.buildDays(
            visibleMonth: visibleMonth,
            selectedDate: selectedDate,
            events: monthEvents
        )
    }

    private func rebuildSelectedDateEvents() {
        selectedDateEvents = monthEvents
            .filter { workCalendar.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay {
                    return lhs.isAllDay && !rhs.isAllDay
                }
                return lhs.startDate < rhs.startDate
            }
    }

    private func rebuildTodayIndicator() {
        guard permissionState == .fullAccess else {
            todayEventCount = 0
            hasTodayEvents = false
            return
        }

        let today = Date()
        let start = workCalendar.startOfDay(for: today)
        let end = workCalendar.date(byAdding: .day, value: 1, to: start) ?? today

        let todayEvents = calendarService.fetchEvents(from: start, to: end)

        todayEventCount = todayEvents.count
        hasTodayEvents = todayEventCount > 0
    }
}
