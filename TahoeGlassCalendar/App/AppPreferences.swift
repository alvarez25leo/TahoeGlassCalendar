import Foundation

/// Wrapper de UserDefaults para preferencias persistidas a través de launches.
enum AppPreferences {
    private enum Keys {
        static let countdownHidden = "tgc.countdownHidden"
        static let notificationLeadMinutes = "tgc.notificationLeadMinutes"
    }

    static var countdownHidden: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.countdownHidden) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.countdownHidden) }
    }
}
