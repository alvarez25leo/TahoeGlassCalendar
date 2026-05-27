import EventKit
import Foundation
import os

enum CalendarServiceError: LocalizedError {
    case noCalendarSelected
    case calendarNotFound
    case eventNotFound
    case saveFailed(Error)
    case deleteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noCalendarSelected:
            return "Seleccioná un calendario para guardar el evento."
        case .calendarNotFound:
            return "El calendario seleccionado ya no está disponible."
        case .eventNotFound:
            return "El evento ya no existe."
        case .saveFailed(let error):
            return "No se pudo guardar el evento: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "No se pudo eliminar el evento: \(error.localizedDescription)"
        }
    }
}

final class CalendarService: CalendarServiceProtocol, @unchecked Sendable {
    private let store = EKEventStore()

    var eventStore: EKEventStore { store }

    // MARK: - EKEventStoreChanged → AsyncStream
    //
    // Convertimos la NSNotification a un AsyncStream<Void> para que el ViewModel
    // pueda suscribirse sin acoplarse al menubar ni a NotificationCenter. Cada
    // emisión = "alguien tocó el store; revalidá lo que tengas cacheado".
    let eventStoreChanges: AsyncStream<Void>
    private let changesContinuation: AsyncStream<Void>.Continuation
    private var notificationToken: NSObjectProtocol?

    init() {
        var continuation: AsyncStream<Void>.Continuation!
        let stream = AsyncStream<Void>(bufferingPolicy: .bufferingNewest(1)) { cont in
            continuation = cont
        }
        self.eventStoreChanges = stream
        self.changesContinuation = continuation

        notificationToken = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: nil
        ) { [weak self] _ in
            self?.changesContinuation.yield()
        }
    }

    deinit {
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
        }
        changesContinuation.finish()
    }

    func authorizationStatus() -> CalendarPermissionState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .fullAccess:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            AppLogger.calendar.error("Calendar permission error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEventItem] {
        let store = self.store
        return await Task.detached(priority: .userInitiated) {
            let predicate = store.predicateForEvents(
                withStart: startDate,
                end: endDate,
                calendars: nil
            )

            let items: [CalendarEventItem] = store.events(matching: predicate)
                .filter { $0.status != .canceled }
                .map { event in
                    let safeTitle: String
                    if let title = event.title, !title.isEmpty {
                        safeTitle = title
                    } else {
                        safeTitle = "Sin título"
                    }

                    return CalendarEventItem(
                        id: event.eventIdentifier ?? UUID().uuidString,
                        title: safeTitle,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        isAllDay: event.isAllDay,
                        calendarTitle: event.calendar.title,
                        calendarID: event.calendar.calendarIdentifier,
                        calendarColor: event.calendar.cgColor,
                        location: event.location,
                        notes: event.notes,
                        eventIdentifier: event.eventIdentifier
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.isAllDay != rhs.isAllDay {
                        return lhs.isAllDay && !rhs.isAllDay
                    }
                    return lhs.startDate < rhs.startDate
                }

            return items
        }.value
    }

    func availableCalendars() -> [CalendarSource] {
        store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .map { cal in
                CalendarSource(
                    id: cal.calendarIdentifier,
                    title: cal.title,
                    sourceTitle: cal.source?.title ?? "",
                    color: cal.cgColor,
                    allowsModifications: cal.allowsContentModifications
                )
            }
            .sorted { lhs, rhs in
                if lhs.sourceTitle == rhs.sourceTitle {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.sourceTitle.localizedCaseInsensitiveCompare(rhs.sourceTitle) == .orderedAscending
            }
    }

    func defaultCalendarID() -> String? {
        store.defaultCalendarForNewEvents?.calendarIdentifier
    }

    func createEvent(_ draft: NewEventDraft) async throws -> String {
        let store = self.store
        return try await Task.detached(priority: .userInitiated) {
            guard let calendar = store.calendar(withIdentifier: draft.calendarID) else {
                throw CalendarServiceError.calendarNotFound
            }

            let event = EKEvent(eventStore: store)
            event.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            event.location = draft.location.isEmpty ? nil : draft.location
            event.notes = draft.notes.isEmpty ? nil : draft.notes
            event.startDate = draft.startDate
            event.endDate = draft.endDate
            event.isAllDay = draft.isAllDay
            event.calendar = calendar

            do {
                try store.save(event, span: .thisEvent)
                AppLogger.calendar.info("Event created: \(event.eventIdentifier ?? "<no-id>", privacy: .public)")
                return event.eventIdentifier ?? UUID().uuidString
            } catch {
                AppLogger.calendar.error("Save event failed: \(error.localizedDescription, privacy: .public)")
                throw CalendarServiceError.saveFailed(error)
            }
        }.value
    }

    func updateEvent(eventID: String, draft: NewEventDraft) async throws {
        let store = self.store
        try await Task.detached(priority: .userInitiated) {
            guard let event = store.event(withIdentifier: eventID) else {
                throw CalendarServiceError.eventNotFound
            }
            guard let calendar = store.calendar(withIdentifier: draft.calendarID) else {
                throw CalendarServiceError.calendarNotFound
            }

            event.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            event.location = draft.location.isEmpty ? nil : draft.location
            event.notes = draft.notes.isEmpty ? nil : draft.notes
            event.startDate = draft.startDate
            event.endDate = draft.endDate
            event.isAllDay = draft.isAllDay
            event.calendar = calendar

            do {
                try store.save(event, span: .thisEvent)
                AppLogger.calendar.info("Event updated: \(eventID, privacy: .public)")
            } catch {
                AppLogger.calendar.error("Update event failed: \(error.localizedDescription, privacy: .public)")
                throw CalendarServiceError.saveFailed(error)
            }
        }.value
    }

    func deleteEvent(eventID: String) async throws {
        let store = self.store
        try await Task.detached(priority: .userInitiated) {
            guard let event = store.event(withIdentifier: eventID) else {
                throw CalendarServiceError.eventNotFound
            }
            do {
                try store.remove(event, span: .thisEvent)
                AppLogger.calendar.info("Event deleted: \(eventID, privacy: .public)")
            } catch {
                AppLogger.calendar.error("Delete event failed: \(error.localizedDescription, privacy: .public)")
                throw CalendarServiceError.deleteFailed(error)
            }
        }.value
    }
}
