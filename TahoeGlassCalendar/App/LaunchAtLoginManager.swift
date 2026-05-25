import Foundation
import ServiceManagement
import Combine
import os

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled: Bool = false

    private let service = SMAppService.mainApp

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = service.status == .enabled
    }

    func toggle() {
        do {
            if isEnabled {
                try service.unregister()
                AppLogger.login.info("Login item unregistered")
            } else {
                try service.register()
                AppLogger.login.info("Login item registered")
            }
        } catch {
            AppLogger.login.error("Login item toggle failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }
}
