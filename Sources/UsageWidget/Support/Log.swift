import OSLog

/// Centralized loggers. View in Console.app or `log stream --predicate 'subsystem == "com.flukelaster.usagewidget"'`.
enum Log {
    private static let subsystem = "com.flukelaster.usagewidget"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let engine = Logger(subsystem: subsystem, category: "engine")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")
}
