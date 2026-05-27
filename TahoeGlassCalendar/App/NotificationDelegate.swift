import AppKit
import UserNotifications
import os

/// Maneja presentación foreground y acciones (Abrir / Snooze 1min) de las
/// notificaciones de próximo evento.
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private let opener = AppleCalendarOpener()

    private override init() { super.init() }

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    // Mostrar banner aunque la app esté en foreground (somos menu bar).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionID = response.actionIdentifier

        Task { @MainActor [weak self] in
            guard let self else {
                completionHandler()
                return
            }
            await self.handle(actionID: actionID, userInfo: userInfo, original: response.notification.request)
            completionHandler()
        }
    }

    @MainActor
    private func handle(actionID: String, userInfo: [AnyHashable: Any], original: UNNotificationRequest) async {
        switch actionID {
        case "OPEN_EVENT", UNNotificationDefaultActionIdentifier:
            let date: Date
            if let stamp = userInfo["startDate"] as? TimeInterval {
                date = Date(timeIntervalSince1970: stamp)
            } else {
                date = Date()
            }
            opener.openCalendar(at: date)

        case "SNOOZE_5MIN":
            await snooze(original: original, by: 5 * 60)

        case "SNOOZE_15MIN":
            await snooze(original: original, by: 15 * 60)

        case "SNOOZE_1H":
            await snooze(original: original, by: 60 * 60)

        case UNNotificationDismissActionIdentifier:
            break

        default:
            break
        }
    }

    @MainActor
    private func snooze(original: UNNotificationRequest, by seconds: TimeInterval) async {
        let content = original.content.mutableCopy() as? UNMutableNotificationContent ?? UNMutableNotificationContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let req = UNNotificationRequest(
            identifier: original.identifier + ".snooze",
            content: content,
            trigger: trigger
        )
        do {
            try await UNUserNotificationCenter.current().add(req)
            AppLogger.notifications.info("Snoozed notification for \(Int(seconds), privacy: .public)s")
        } catch {
            AppLogger.notifications.error("Snooze failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
