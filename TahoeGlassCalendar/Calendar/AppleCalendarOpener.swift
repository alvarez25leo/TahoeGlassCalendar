import AppKit

final class AppleCalendarOpener {
    func openCalendarApp() {
        let appURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
        let config = NSWorkspace.OpenConfiguration()

        NSWorkspace.shared.openApplication(
            at: appURL,
            configuration: config
        ) { _, error in
            if let error {
                print("Failed to open Calendar.app:", error)
            }
        }
    }
}
