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

    @Published private(set) var availableCalendars: [CalendarSource] = []
    @Published var quickAddDate: Date?
    @Published var quickAddError: String?
    @Published var editingEvent: CalendarEventItem?
    @Published var pendingDeleteEvent: CalendarEventItem?

    /// Próximo evento "real" (timed, futuro) para countdown + notificación.
    /// Mira primero hoy, luego días siguientes dentro de la ventana cargada.
    @Published private(set) var upcomingEvent: CalendarEventItem?
    @Published var countdownHidden: Bool {
        didSet { AppPreferences.countdownHidden = countdownHidden }
    }

    var composerIsPresented: Bool {
        quickAddDate != nil
    }

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
        self.countdownHidden = AppPreferences.countdownHidden
    }

    func toggleCountdownHidden() {
        countdownHidden = !countdownHidden
        if !countdownHidden {
            // Al re-mostrar, pedir permiso de notificación de manera diferida.
            Task { await NotificationScheduler.shared.requestAuthorizationIfNeeded() }
        }
    }

    func bootstrap() async {
        permissionState = calendarService.authorizationStatus()
        AppLogger.calendar.info("Bootstrap: permission=\(String(describing: self.permissionState), privacy: .public)")

        if permissionState == .notDetermined {
            return
        }

        if permissionState == .fullAccess {
            availableCalendars = calendarService.availableCalendars()
            await refreshAll()
        }
    }

    func requestCalendarAccess() async {
        let granted = await calendarService.requestAccess()
        permissionState = granted ? .fullAccess : calendarService.authorizationStatus()

        if granted {
            availableCalendars = calendarService.availableCalendars()
            await refreshAll()
        }
    }

    func refreshAll() async {
        guard permissionState == .fullAccess else {
            rebuildTodayIndicator(from: nil)
            return
        }

        let gridRange = CalendarDateUtils.gridRange(for: visibleMonth, calendar: workCalendar)
        let events = await calendarService.fetchEvents(from: gridRange.start, to: gridRange.end)
        gridEvents = events

        rebuildDays()
        rebuildSelectedDateEvents()
        rebuildTodayIndicator(from: events)
        AppLogger.calendar.debug("refreshAll: \(events.count) events in grid range")
    }

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

    func handleDayChange() async {
        AppLogger.calendar.info("Day changed: re-rendering")
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

    func moveSelection(by days: Int) async {
        guard let newDate = workCalendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = newDate

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

    var isViewingCurrentMonth: Bool {
        workCalendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Quick add

    func presentQuickAdd(on date: Date) {
        // Refrescamos los calendarios en caso de cambios externos.
        if permissionState == .fullAccess {
            availableCalendars = calendarService.availableCalendars()
        }
        editingEvent = nil
        quickAddError = nil
        quickAddDate = date
    }

    func presentEdit(for event: CalendarEventItem) {
        if permissionState == .fullAccess {
            availableCalendars = calendarService.availableCalendars()
        }
        quickAddError = nil
        editingEvent = event
        quickAddDate = event.startDate
    }

    func dismissQuickAdd() {
        quickAddDate = nil
        editingEvent = nil
        quickAddError = nil
    }

    /// Marca el row para mostrar confirmacion inline. NO usa NSAlert porque
    /// abre conflicto de focus con NSPopover.transient (genera UI freeze).
    func requestDelete(_ event: CalendarEventItem) {
        pendingDeleteEvent = event
    }

    func cancelDelete() {
        pendingDeleteEvent = nil
    }

    func confirmDelete(_ event: CalendarEventItem) async {
        // Clear de inmediato para que la UI vuelva al estado normal sin esperar
        // el round-trip de EventKit/iCloud.
        if pendingDeleteEvent?.id == event.id {
            pendingDeleteEvent = nil
        }

        // Optimistic update: removemos el evento de la lista en memoria antes
        // de que EventKit termine, para que la UI responda al instante.
        gridEvents.removeAll { $0.id == event.id }
        rebuildSelectedDateEvents()
        rebuildDays()

        let id = event.eventIdentifier ?? event.id

        do {
            try await calendarService.deleteEvent(eventID: id)
            // Refresh para recoger cualquier sync. Si falla, el observer de
            // EKEventStoreChanged lo emparejará.
            await refreshAll()
        } catch {
            AppLogger.calendar.error("Delete failed: \(error.localizedDescription, privacy: .public)")
            // Restauramos refrescando.
            await refreshAll()
        }
    }

    func createNewEvent() {
        // Botón "Crear" del footer: abre el composer sobre la fecha seleccionada.
        presentQuickAdd(on: defaultQuickAddDate(for: selectedDate))
    }

    /// Si el usuario clickea derecho un día, el composer arranca con hora 9-10 am
    /// (o ahora+1h si es hoy y son después de las 9). Solo afecta la sugerencia inicial.
    func defaultQuickAddDate(for date: Date) -> Date {
        let calendar = workCalendar
        if calendar.isDateInToday(date) {
            let now = Date()
            // Redondea a la próxima media hora.
            var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            let minute = comps.minute ?? 0
            comps.minute = minute < 30 ? 30 : 0
            if minute >= 30 {
                comps.hour = (comps.hour ?? 0) + 1
            }
            return calendar.date(from: comps) ?? date
        } else {
            var comps = calendar.dateComponents([.year, .month, .day], from: date)
            comps.hour = 9
            comps.minute = 0
            return calendar.date(from: comps) ?? date
        }
    }

    func defaultCalendarID() -> String? {
        if let defaultID = calendarService.defaultCalendarID(),
           availableCalendars.contains(where: { $0.id == defaultID }) {
            return defaultID
        }
        return availableCalendars.first?.id
    }

    func saveDraft(_ draft: NewEventDraft) async -> Bool {
        guard draft.isValid else {
            quickAddError = "Falta el título del evento."
            return false
        }
        do {
            if let editing = editingEvent, let id = editing.eventIdentifier ?? Optional(editing.id) {
                try await calendarService.updateEvent(eventID: id, draft: draft)
            } else {
                _ = try await calendarService.createEvent(draft)
            }
            quickAddError = nil
            quickAddDate = nil
            editingEvent = nil
            await refreshAll()
            return true
        } catch {
            quickAddError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            AppLogger.calendar.error("saveDraft failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Rebuild helpers

    private func rebuildDays() {
        days = monthBuilder.buildDays(
            visibleMonth: visibleMonth,
            selectedDate: selectedDate,
            events: gridEvents
        )
    }

    private func rebuildSelectedDateEvents() {
        let dayStart = workCalendar.startOfDay(for: selectedDate)
        guard let dayEnd = workCalendar.date(byAdding: .day, value: 1, to: dayStart) else {
            selectedDateEvents = []
            return
        }

        // Overlap real: el evento toca este dia si [start, end) intersecta [dayStart, dayEnd).
        selectedDateEvents = gridEvents
            .filter { event in
                if event.startDate == event.endDate {
                    return workCalendar.isDate(event.startDate, inSameDayAs: selectedDate)
                }
                return event.startDate < dayEnd && event.endDate > dayStart
            }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay {
                    return lhs.isAllDay && !rhs.isAllDay
                }
                return lhs.startDate < rhs.startDate
            }
    }

    private func rebuildTodayIndicator(from events: [CalendarEventItem]?) {
        guard permissionState == .fullAccess else {
            applyTodayIndicator(events: [])
            return
        }

        let today = Date()
        let start = workCalendar.startOfDay(for: today)
        let end = workCalendar.date(byAdding: .day, value: 1, to: start) ?? today

        if let events = events {
            // Overlap: incluimos eventos multi-dia que cubren hoy.
            let todayEvents = events.filter { event in
                if event.startDate == event.endDate {
                    return event.startDate >= start && event.startDate < end
                }
                return event.startDate < end && event.endDate > start
            }
            applyTodayIndicator(events: todayEvents)
        } else if let cache = todayCache, workCalendar.isDate(cache.0, inSameDayAs: today) {
            applyTodayIndicator(events: cache.1)
        } else {
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

        recomputeUpcomingEvent(now: now)
    }

    /// Próximo evento timed que aún no empezó (o está en curso). Mira hoy primero,
    /// si no hay, busca en los gridEvents (que ya cubren el mes visible). Esto
    /// alimenta el countdown y la notificación T-5min.
    private func recomputeUpcomingEvent(now: Date) {
        let candidate = gridEvents
            .filter { !$0.isAllDay && $0.endDate > now }
            .min(by: { $0.startDate < $1.startDate })

        let previousID = upcomingEvent.map { "\($0.id).\(Int($0.startDate.timeIntervalSince1970))" }
        let newID = candidate.map { "\($0.id).\(Int($0.startDate.timeIntervalSince1970))" }

        upcomingEvent = candidate

        if previousID != newID {
            let target = candidate
            Task { @MainActor in
                await NotificationScheduler.shared.scheduleNotification(for: target)
            }
        }
    }
}
