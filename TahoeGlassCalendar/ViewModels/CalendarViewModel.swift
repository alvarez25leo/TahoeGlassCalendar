import Foundation
import Combine
import os

@MainActor
final class CalendarViewModel: ObservableObject {
    // MARK: - Estado UI publicado (derivado)

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

    /// `true` cuando el sistema no tiene conexión de red. Se usa para mostrar el
    /// aviso de "sin sincronización" en el header. Derivado de `NetworkMonitor`.
    @Published private(set) var isOffline: Bool = false

    @Published var quickAddDate: Date?
    @Published var quickAddError: String?
    @Published var editingEvent: CalendarEventItem?
    @Published var pendingDeleteEvent: CalendarEventItem?

    /// Próximo evento "real" (timed, futuro) para countdown + notificación.
    /// Calculado desde la única fuente de verdad: `gridEvents`.
    @Published private(set) var upcomingEvent: CalendarEventItem?

    @Published var countdownHidden: Bool {
        didSet { AppPreferences.countdownHidden = countdownHidden }
    }

    // MARK: - Búsqueda (quick-win pro)

    @Published var searchQuery: String = ""
    @Published private(set) var searchResults: [SearchResultGroup] = []
    @Published var isSearchActive: Bool = false
    @Published private(set) var isSearchLoading: Bool = false

    struct SearchResultGroup: Identifiable, Equatable {
        let id: String          // dayID
        let date: Date
        let events: [CalendarEventItem]
    }

    var composerIsPresented: Bool {
        quickAddDate != nil
    }

    // MARK: - Source of truth

    /// **Única fuente de verdad** para todo lo que se renderiza en el popover.
    /// Cubre el rango de 42 días del grid del mes visible. Cuando cambia,
    /// `selectedDateEvents`, `days`, `upcomingEvent`, `searchResults` y el
    /// indicador de hoy se recalculan vía `rebuildDerived()`.
    private var gridEvents: [CalendarEventItem] = []
    private var searchEvents: [CalendarEventItem] = []
    private var loadedSearchRange: (start: Date, end: Date)?

    /// Cache para el "hoy" cuando el usuario está navegando por otro mes y
    /// `gridEvents` ya no incluye el día actual. Se invalida al cambiar de día
    /// o al llegar `EKEventStoreChanged`.
    private var offMonthTodayEvents: [CalendarEventItem]?
    private var offMonthTodayDate: Date?

    // MARK: - Dependencias

    private let calendarService: CalendarServiceProtocol
    private let monthBuilder: CalendarMonthBuilder
    private let opener: AppleCalendarOpener
    private let workCalendar: Calendar

    // MARK: - Concurrencia

    /// Generación monotónica para descartar fetches obsoletos (race condition al
    /// navegar rápido entre meses). Sólo gana el último.
    private var fetchGeneration: Int = 0
    private var searchFetchGeneration: Int = 0
    private var storeChangesListener: Task<Void, Never>?
    private var searchCancellable: AnyCancellable?
    private let networkMonitor = NetworkMonitor()
    private var networkCancellable: AnyCancellable?

    private let searchMonthRadius = 3

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

        // Debounce de búsqueda — evita re-filtrar en cada keystroke.
        searchCancellable = $searchQuery
            .removeDuplicates()
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildSearchResults()
            }

        // Estado de conectividad → bandera para el aviso de sincronización.
        networkCancellable = networkMonitor.$isConnected
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isOffline = !connected
            }
    }

    deinit {
        storeChangesListener?.cancel()
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        permissionState = calendarService.authorizationStatus()
        AppLogger.calendar.info("Bootstrap: permission=\(String(describing: self.permissionState), privacy: .public)")

        startObservingStoreChanges()

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

    private func startObservingStoreChanges() {
        guard storeChangesListener == nil else { return }
        storeChangesListener = Task { [weak self] in
            guard let self else { return }
            for await _ in self.calendarService.eventStoreChanges {
                if Task.isCancelled { return }
                AppLogger.calendar.info("EKEventStoreChanged received → refresh")
                // Invalidamos cache de hoy off-month porque el evento podría
                // ser de hoy aunque no estemos viendo ese mes.
                await self.invalidateOffMonthCache()
                await self.refreshAll()
            }
        }
    }

    private func invalidateOffMonthCache() async {
        offMonthTodayEvents = nil
        offMonthTodayDate = nil
    }

    // MARK: - Refresh

    func refreshAll() async {
        guard permissionState == .fullAccess else {
            gridEvents = []
            searchEvents = []
            loadedSearchRange = nil
            isSearchLoading = false
            rebuildDerived(now: Date())
            return
        }

        fetchGeneration += 1
        let myGeneration = fetchGeneration
        isLoading = true

        let gridRange = CalendarDateUtils.gridRange(for: visibleMonth, calendar: workCalendar)
        let events = await calendarService.fetchEvents(from: gridRange.start, to: gridRange.end)

        // Si otra llamada empezó después de mí, descarto este resultado.
        guard myGeneration == fetchGeneration else {
            AppLogger.calendar.debug("refreshAll gen=\(myGeneration) discarded (current=\(self.fetchGeneration))")
            return
        }

        gridEvents = events
        isLoading = false
        if isSearchActive {
            searchEvents = []
            loadedSearchRange = nil
        }
        rebuildDerived(now: Date())

        if isSearchActive {
            Task { [weak self] in await self?.refreshSearchWindow() }
        }

        // Si el día de hoy no está en el grid visible, refrescamos el cache
        // off-month en background para que el menubar siga reflejándolo.
        if !todayIsInGridRange(gridRange) {
            Task { [weak self] in await self?.refreshOffMonthTodayCache() }
        } else {
            offMonthTodayEvents = nil
            offMonthTodayDate = nil
        }

        AppLogger.calendar.debug("refreshAll: \(events.count) events in grid range")
    }

    /// Refresh ligero del indicador de hoy — usado por el timer del menubar cada
    /// minuto. Si gridEvents cubre hoy, no hace fetch; si no, mantiene el cache.
    func refreshTodayIndicator() async {
        guard permissionState == .fullAccess else {
            rebuildDerived(now: Date())
            return
        }

        let gridRange = CalendarDateUtils.gridRange(for: visibleMonth, calendar: workCalendar)
        if todayIsInGridRange(gridRange) {
            rebuildDerived(now: Date())
        } else {
            await refreshOffMonthTodayCache()
            rebuildDerived(now: Date())
        }
    }

    private func refreshOffMonthTodayCache() async {
        let today = Date()
        let start = workCalendar.startOfDay(for: today)
        let end = workCalendar.date(byAdding: .day, value: 1, to: start) ?? today

        let events = await calendarService.fetchEvents(from: start, to: end)
        offMonthTodayEvents = events
        offMonthTodayDate = start
        // Si seguimos en el mismo día (race), refresca el indicador.
        rebuildDerived(now: Date())
    }

    func handleDayChange() async {
        AppLogger.calendar.info("Day changed: re-rendering")
        await invalidateOffMonthCache()
        await refreshAll()
    }

    // MARK: - Navegación

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
        rebuildDerived(now: Date())
    }

    func moveSelection(by days: Int) async {
        guard let newDate = workCalendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = newDate

        if !workCalendar.isDate(newDate, equalTo: visibleMonth, toGranularity: .month) {
            visibleMonth = newDate
            await refreshAll()
        } else {
            rebuildDerived(now: Date())
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

    // MARK: - Countdown toggle

    func toggleCountdownHidden() {
        countdownHidden = !countdownHidden
        if !countdownHidden {
            Task { await NotificationScheduler.shared.requestAuthorizationIfNeeded() }
        }
    }

    // MARK: - Búsqueda

    func toggleSearch() {
        isSearchActive.toggle()
        if isSearchActive {
            Task { [weak self] in await self?.refreshSearchWindow() }
        } else {
            searchQuery = ""
            searchResults = []
            searchEvents = []
            loadedSearchRange = nil
            isSearchLoading = false
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchEvents = []
        loadedSearchRange = nil
        isSearchLoading = false
        isSearchActive = false
    }

    var searchPlaceholder: String {
        "Buscar en ±\(searchMonthRadius) meses…"
    }

    var searchScopeLabel: String {
        "±\(searchMonthRadius) meses"
    }

    private func refreshSearchWindow() async {
        guard permissionState == .fullAccess else {
            searchEvents = []
            loadedSearchRange = nil
            searchResults = []
            isSearchLoading = false
            return
        }

        searchFetchGeneration += 1
        let myGeneration = searchFetchGeneration
        isSearchLoading = true

        let range = searchRange(for: visibleMonth)
        let events = await calendarService.fetchEvents(from: range.start, to: range.end)

        guard myGeneration == searchFetchGeneration else {
            return
        }

        searchEvents = events
        loadedSearchRange = range
        isSearchLoading = false
        rebuildSearchResults()
    }

    private func rebuildSearchResults() {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            searchResults = []
            return
        }

        let sourceEvents = loadedSearchRange == nil ? gridEvents : searchEvents
        let matches = sourceEvents.filter { event in
            if event.title.lowercased().contains(q) { return true }
            if let loc = event.location?.lowercased(), loc.contains(q) { return true }
            if let notes = event.notes?.lowercased(), notes.contains(q) { return true }
            return false
        }

        // Agrupar por día para una lista jerárquica.
        let grouped = Dictionary(grouping: matches) { event in
            CalendarDateUtils.dayID(for: event.startDate, calendar: workCalendar)
        }

        searchResults = grouped
            .compactMap { (dayID, events) -> SearchResultGroup? in
                guard let first = events.first else { return nil }
                let dayStart = workCalendar.startOfDay(for: first.startDate)
                let sorted = events.sorted { lhs, rhs in
                    if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay && !rhs.isAllDay }
                    return lhs.startDate < rhs.startDate
                }
                return SearchResultGroup(id: dayID, date: dayStart, events: sorted)
            }
            .sorted { $0.date < $1.date }
    }

    private func searchRange(for date: Date) -> (start: Date, end: Date) {
        let monthStart = CalendarDateUtils.startOfMonth(for: date, calendar: workCalendar)
        let start = workCalendar.date(byAdding: .month, value: -searchMonthRadius, to: monthStart) ?? monthStart
        let end = workCalendar.date(byAdding: .month, value: searchMonthRadius + 1, to: monthStart) ?? monthStart
        return (start, end)
    }

    // MARK: - Quick add / edit / delete

    func presentQuickAdd(on date: Date) {
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

    func requestDelete(_ event: CalendarEventItem) {
        pendingDeleteEvent = event
    }

    func cancelDelete() {
        pendingDeleteEvent = nil
    }

    func confirmDelete(_ event: CalendarEventItem) async {
        if pendingDeleteEvent?.id == event.id {
            pendingDeleteEvent = nil
        }

        // Optimistic update sobre la única fuente de verdad.
        gridEvents.removeAll { $0.id == event.id }
        searchEvents.removeAll { $0.id == event.id }
        rebuildDerived(now: Date())

        let id = event.eventIdentifier ?? event.id

        do {
            try await calendarService.deleteEvent(eventID: id)
            await refreshAll()
        } catch {
            AppLogger.calendar.error("Delete failed: \(error.localizedDescription, privacy: .public)")
            await refreshAll()
        }
    }

    func createNewEvent() {
        presentQuickAdd(on: defaultQuickAddDate(for: selectedDate))
    }

    func defaultQuickAddDate(for date: Date) -> Date {
        let calendar = workCalendar
        if calendar.isDateInToday(date) {
            let now = Date()
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

    // MARK: - Derived rebuild (única fuente → todo lo demás)

    private func rebuildDerived(now: Date) {
        rebuildDays()
        rebuildSelectedDateEvents()
        rebuildTodayIndicator(now: now)
        rebuildSearchResults()
    }

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

    private func rebuildTodayIndicator(now: Date) {
        guard permissionState == .fullAccess else {
            todayEventCount = 0
            hasTodayEvents = false
            nextTodayEvent = nil
            upcomingEvent = nil
            return
        }

        let start = workCalendar.startOfDay(for: now)
        let end = workCalendar.date(byAdding: .day, value: 1, to: start) ?? now

        // Si gridEvents cubre hoy, lo derivamos desde ahí. Si no, usamos cache
        // off-month (alimentado por refreshOffMonthTodayCache).
        let todayEvents: [CalendarEventItem]
        let gridRange = CalendarDateUtils.gridRange(for: visibleMonth, calendar: workCalendar)
        if todayIsInGridRange(gridRange) {
            todayEvents = gridEvents.filter { event in
                if event.startDate == event.endDate {
                    return event.startDate >= start && event.startDate < end
                }
                return event.startDate < end && event.endDate > start
            }
        } else if let cached = offMonthTodayEvents,
                  let cacheDate = offMonthTodayDate,
                  workCalendar.isDate(cacheDate, inSameDayAs: now) {
            todayEvents = cached
        } else {
            todayEvents = []
        }

        todayEventCount = todayEvents.count
        hasTodayEvents = !todayEvents.isEmpty
        nextTodayEvent = todayEvents
            .filter { !$0.isAllDay && $0.endDate > now }
            .min(by: { $0.startDate < $1.startDate })
            ?? todayEvents.first

        recomputeUpcomingEvent(now: now, todayEvents: todayEvents)
    }

    /// Próximo evento timed: lo busca primero en hoy, luego en el resto del grid.
    private func recomputeUpcomingEvent(now: Date, todayEvents: [CalendarEventItem]) {
        let pool = gridEvents.isEmpty ? todayEvents : gridEvents
        let candidate = pool
            .filter { !$0.isAllDay && $0.endDate > now }
            .min(by: { $0.startDate < $1.startDate })

        let previousKey = upcomingEvent.map { "\($0.id).\(Int($0.startDate.timeIntervalSince1970))" }
        let newKey = candidate.map { "\($0.id).\(Int($0.startDate.timeIntervalSince1970))" }

        upcomingEvent = candidate

        if previousKey != newKey {
            let target = candidate
            Task { @MainActor in
                await NotificationScheduler.shared.scheduleNotification(for: target)
            }
        }
    }

    private func todayIsInGridRange(_ range: (start: Date, end: Date)) -> Bool {
        let now = Date()
        return now >= range.start && now < range.end
    }
}
