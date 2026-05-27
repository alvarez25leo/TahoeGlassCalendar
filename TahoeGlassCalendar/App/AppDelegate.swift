import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            NotificationDelegate.shared.install()
            NotificationScheduler.shared.bootstrap()
            // Pedir permiso temprano (silencioso si ya decidió).
            await NotificationScheduler.shared.requestAuthorizationIfNeeded()
        }

        statusBarController = StatusBarController()
        statusBarController?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.stop()
    }
}
