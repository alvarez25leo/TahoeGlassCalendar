import Foundation

/// Wrapper de UserDefaults para preferencias persistidas a través de launches.
enum AppPreferences {
    private enum Keys {
        static let countdownHidden = "tgc.countdownHidden"
        static let notificationLeadMinutes = "tgc.notificationLeadMinutes"
        static let showUpcomingInMenuBar = "tgc.showUpcomingInMenuBar"
    }

    static var countdownHidden: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.countdownHidden) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.countdownHidden) }
    }

    /// Mostrar título y hora del próximo evento junto al icono del menubar
    /// cuando esté dentro de los próximos 90 minutos. Default: activado.
    static var showUpcomingInMenuBar: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.showUpcomingInMenuBar) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.showUpcomingInMenuBar)
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.showUpcomingInMenuBar) }
    }
}
