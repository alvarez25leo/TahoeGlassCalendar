import Foundation
import UserNotifications
import os

/// Agenda notificaciones T-5min para el próximo evento.
/// Idempotente: re-agendar el mismo evento no genera duplicados (mismo identifier).
@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let leadMinutes: Int = 5
    private let categoryID = "TGC_UPCOMING_EVENT"
    private let identifierPrefix = "tgc.upcoming."

    /// Track del último identifier agendado, para limpiar cuando cambia el evento.
    private var lastScheduledIdentifier: String?
    private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {}

    // MARK: - Setup

    func bootstrap() {
        registerCategory()
        Task { await refreshAuthorizationStatus() }
    }

    private func registerCategory() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_EVENT",
            title: "Abrir en Calendar",
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_1MIN",
            title: "Recordar en 1 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [openAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    private func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Pide permiso si está en notDetermined. No molesta al usuario si ya decidió.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await refreshAuthorizationStatus()
                AppLogger.notifications.info("Notification authorization: \(granted, privacy: .public)")
                return granted
            } catch {
                AppLogger.notifications.error("Auth request failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    /// Agenda notificación para `event` a `event.startDate - leadMinutes`.
    /// Si ya hay una agendada para el mismo evento, no hace nada. Si es otra,
    /// cancela la anterior antes de agendar la nueva.
    func scheduleNotification(for event: CalendarEventItem?) async {
        guard let event else {
            await cancelAllScheduled()
            return
        }

        let identifier = identifier(for: event)

        // Mismo evento ya agendado: noop.
        if lastScheduledIdentifier == identifier {
            // Verificar que sigue pendiente (por si el sistema lo descartó).
            let pending = await center.pendingNotificationRequests()
            if pending.contains(where: { $0.identifier == identifier }) {
                return
            }
        }

        await cancelAllScheduled()

        // Verificar permiso (silencioso — no pedir aquí).
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            AppLogger.notifications.debug("Skipping schedule: not authorized")
            return
        }

        // Calcular fire date.
        let fireDate = event.startDate.addingTimeInterval(TimeInterval(-leadMinutes * 60))
        let now = Date()
        guard fireDate > now else {
            AppLogger.notifications.debug("Skip: fire date in past for \(event.title, privacy: .private)")
            return
        }

        let content = buildContent(for: event)
        let interval = fireDate.timeIntervalSince(now)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            lastScheduledIdentifier = identifier
            AppLogger.notifications.info("Scheduled T-\(self.leadMinutes)min for event id=\(event.id, privacy: .public)")
        } catch {
            AppLogger.notifications.error("Schedule failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func buildContent(for event: CalendarEventItem) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.subtitle = "En \(leadMinutes) minutos"

        var bodyParts: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        bodyParts.append("Comienza a las \(formatter.string(from: event.startDate))")
        if let location = event.location, !location.isEmpty {
            bodyParts.append("📍 \(location)")
        }
        content.body = bodyParts.joined(separator: "\n")

        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            "eventID": event.eventIdentifier ?? event.id,
            "startDate": event.startDate.timeIntervalSince1970
        ]
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        return content
    }

    // MARK: - Cleanup

    func cancelAllScheduled() async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        if !ours.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ours)
            AppLogger.notifications.debug("Cancelled \(ours.count) pending")
        }
        lastScheduledIdentifier = nil
    }

    private func identifier(for event: CalendarEventItem) -> String {
        // Incluye el timestamp del start para que un evento movido re-agende.
        let stamp = Int(event.startDate.timeIntervalSince1970)
        let eventKey = event.eventIdentifier ?? event.id
        return "\(identifierPrefix)\(eventKey).\(stamp)"
    }
}
