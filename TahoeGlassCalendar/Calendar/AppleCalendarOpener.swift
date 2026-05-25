import AppKit
import Foundation
import os

final class AppleCalendarOpener {
    private let appURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")

    func openCalendarApp() {
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            if let error {
                AppLogger.opener.error("openCalendarApp failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Abre Calendar.app y navega a una fecha exacta via AppleScript.
    /// Si AppleScript falla (sin permiso de Automation), cae a abrir solo la app.
    func openCalendar(at date: Date) {
        openCalendarApp()
        runViewAtScript(for: date)
    }

    /// Abre Calendar.app en la fecha indicada y dispara Cmd+N para crear evento.
    /// Requiere permiso de Automation. Si falla, abre Calendar.app a secas.
    func createNewEvent(at date: Date) {
        openCalendarApp()
        runNewEventScript(for: date)
    }

    private func runViewAtScript(for date: Date) {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return }

        let script = """
        tell application "Calendar"
            activate
            set targetDate to (current date)
            set year of targetDate to \(y)
            set month of targetDate to \(m)
            set day of targetDate to \(d)
            set time of targetDate to 0
            view calendar at targetDate
        end tell
        """
        runScript(script, label: "view-at")
    }

    private func runNewEventScript(for date: Date) {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return }

        let script = """
        tell application "Calendar"
            activate
            set targetDate to (current date)
            set year of targetDate to \(y)
            set month of targetDate to \(m)
            set day of targetDate to \(d)
            set time of targetDate to 0
            view calendar at targetDate
        end tell
        tell application "System Events"
            tell process "Calendar"
                keystroke "n" using command down
            end tell
        end tell
        """
        runScript(script, label: "new-event")
    }

    private func runScript(_ source: String, label: String) {
        Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            if let script = NSAppleScript(source: source) {
                let result = script.executeAndReturnError(&error)
                if let error = error {
                    AppLogger.opener.error("AppleScript [\(label, privacy: .public)] failed: \(String(describing: error), privacy: .public)")
                } else {
                    AppLogger.opener.debug("AppleScript [\(label, privacy: .public)] ok: \(result.stringValue ?? "")")
                }
            }
        }
    }
}
