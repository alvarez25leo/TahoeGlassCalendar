import Foundation
import os

enum AppLogger {
    static let subsystem = "com.manuel.tahoeglasscalendar"

    static let calendar = Logger(subsystem: subsystem, category: "calendar")
    static let menubar = Logger(subsystem: subsystem, category: "menubar")
    static let popover = Logger(subsystem: subsystem, category: "popover")
    static let opener = Logger(subsystem: subsystem, category: "opener")
    static let login = Logger(subsystem: subsystem, category: "login")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
}
