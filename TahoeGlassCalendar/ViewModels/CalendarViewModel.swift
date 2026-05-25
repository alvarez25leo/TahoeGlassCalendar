import Foundation
import Combine
import os

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published private(set) var permissionState: CalendarPermissionState = .notDetermined
    @Published var visibleMonth: Date = Date()
    @Published var selectedDate: Date = Date()

    @Published private(set) var days: [CalendarDayItem] = []
    @Published private(set) var selectedDateEvents: [CalendarEventItem] = []
    @Published private(set) var todayEventCount: Int = 0
    @Published private(set) var hasTodayEvents: Bool = false
    @Published private(set) var nextTodayEvent: CalendarEventItem?
    @Published private(set) var isLoading: Bool = false

    private let calendarService: CalendarServiceProtocol
    private let monthBuilder: CalendarMonthBuilder
    private let opener: AppleCalendarOpener
    private let workCalendar: Calendar

    private var gridEvents: [CalendarEventItem] = []
    private var todayCache: (Date, [CalendarEventItem])?

    init(
        calendarService: CalendarServiceProtocol = CalendarService(),
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
        AppLogger.calendar.info("Bootstrap: permission=\(String(describing: self.permissionState), privacy: .public)")

        if permissionState == .notDetermined {
            return
        }

        if permissionState == .fullAccess {
            await refreshAll()
        }
    }

    func requestCalendarAccess() async {
        let granted = await calendarService.requestAccess()
        permissionState = granted ? .fullAccess : calendarService.authorizationStatus()

        if granted {
            await refreshAll()
        }
    }

    /// Refresh completo: trae eventos del grid (42 días) y reconstruye todo.
    /// Llamar al abrir el popover y al cambiar de mes.
    func refreshAll() async {
        guard permissionState == .fullAccess else {
            rebuildTodayIndicator(from: nil)
            return
        }

        // No toggleamos isLoading aquí para evitar layout shifts en la UI.
        // El fetch corre en Task.detached (no bloquea main actor).
        let gridRange = CalendarDateUtils.gridRange(for: visibleMonth, calendar: workCalendar)
        let events = await calendarService.fetchEvents(from: gridRange.start, to: gridRange.end)
        gridEvents = events

        rebuildDays()
        rebuildSelectedDateEvents()
        rebuildTodayIndicator(from: events)
        AppLogger.calendar.debug("refreshAll: \(events.count) events in grid range")
    }

    /// Refresh barato: solo el conteo/indicador de "hoy".
    /// Llamar cada 60 s y en NSCalendarDayChanged.
    func refreshTodayIndicator() async {
        guard permissionState == .fullAccess else {
            rebuildTodayIndicator(from: nil)
            return
        }

        let today = Date()
        let start = workCalendar.startOfDay(for: today)
        let end = workCalendar.date(byAdding: .day, value: 1, to: start) ?? today

        let events = await calendarService.fetchEvents(from: start, to: end)
        todayCache = (start, events)

        applyTodayIndicator(events: events)
    }

    /// Forzar refresh cuando cambia el día calendario (cruce de medianoche).
    func handleDayChange() async {
        AppLogger.calendar.info("Day changed: re-rendering")
        // Rebuild local arrays con un selectedDate "hoy" si el visibleMonth es el actual.
        if workCalendar.isDateInToday(selectedDate) == false &&
           workCalendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month) {
            // mantenemos selectedDate pero forzamos rebuild para mover el "isToday".
        }
        await refreshAll()
    }

    func goToPreviousMonth() async {
        if let newMonth = workCalendar.date(byAdding: .month, value: -1, to: visibleMonth) {
            visibleMonth = newMonth
        }
        await refreshAll()
    }

    func goToNextMonth() async {
        if let newMonth = workCalendar.date(byAdding: .month, value: 1, to: visibleMonth) {
            visibleMonth = newMonth
        }
        await refreshAll()
    }

    func goToToday() async {
        visibleMonth = Date()
        selectedDate = Date()
        await refreshAll()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        rebuildDays()
        rebuildSelectedDateEvents()
    }

    /// Mover el día seleccionado N días (para flechas del teclado).
    func moveSelection(by days: Int) async {
        guard let newDate = workCalendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = newDate

        // Si caímos fuera del mes visible, navegar.
        if !workCalendar.isDate(newDate, equalTo: visibleMonth, toGranularity: .month) {
            visibleMonth = newDate
            await refreshAll()
        } else {
            rebuildDays()
            rebuildSelectedDateEvents()
        }
    }

    func openCalendar() {
        opener.openCalendar(at: selectedDate)
    }

    func openCalendarBasic() {
        opener.openCalendarApp()
    }

    func openEvent(_ event: CalendarEventItem) {
        opener.openCalendar(at: event.startDate)
    }

    func createNewEvent() {
        opener.createNewEvent(at: selectedDate)
    }

    var isViewingCurrentMonth: Bool {
        workCalendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month)
    }

    private func rebuildDays() {
        days = monthBuilder.buildDays(
            visibleMonth: visibleMonth,
            selectedDate: selectedDate,
            events: gridEvents
        )
    }

    private func rebuildSelectedDateEvents() {
        selectedDateEvents = gridEvents
            .filter { workCalendar.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay {
                    return lhs.isAllDay && !rhs.isAllDay
                }
                return lhs.startDate < rhs.startDate
            }
    }

    /// Usa el cache local (gridEvents) si "hoy" cae dentro del rango.
    /// Si no, deja en cero (refresh asincrónico lo arreglará en background).
    private func rebuildTodayIndicator(from events: [CalendarEventItem]?) {
        guard permissionState == .fullAccess else {
            applyTodayIndicator(events: [])
            return
        }

        let today = Date()
        let start = workCalendar.startOfDay(for: today)
        let end = workCalendar.date(byAdding: .day, value: 1, to: start) ?? today

        if let events = events {
            let todayEvents = events.filter { $0.startDate >= start && $0.startDate < end }
            applyTodayIndicator(events: todayEvents)
        } else if let cache = todayCache, workCalendar.isDate(cache.0, inSameDayAs: today) {
            applyTodayIndicator(events: cache.1)
        } else {
            // No data yet; mantener valores previos pero disparar fetch.
            Task { [weak self] in
                await self?.refreshTodayIndicator()
            }
        }
    }

    private func applyTodayIndicator(events: [CalendarEventItem]) {
        let now = Date()
        todayEventCount = events.count
        hasTodayEvents = !events.isEmpty
        nextTodayEvent = events
            .filter { !$0.isAllDay && $0.endDate > now }
            .min(by: { $0.startDate < $1.startDate })
            ?? events.first
    }
}
