import Foundation
import ServiceManagement

/// Launch-at-login via the modern `SMAppService` API. The live source of truth is the system, so
/// the UI reads `isEnabled` rather than a stored bool (the user can change it in System Settings).
/// Requires a properly bundled, signed `.app` (the packaging script produces one).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
