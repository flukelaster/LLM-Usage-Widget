import Foundation
import Observation

/// User-facing settings, persisted to `UserDefaults`. `@Observable` so the UI and the menu-bar
/// label react to changes. Providers are enabled-by-default: we store the *disabled* set, so a
/// newly-added provider shows up automatically instead of being hidden by an old persisted list.
@MainActor
@Observable
final class SettingsModel {
    enum MenuBarDisplay: String, CaseIterable, Codable, Sendable, Identifiable {
        case iconOnly
        case iconAndPercent
        case compact

        var id: String { rawValue }
        var title: String {
            switch self {
            case .iconOnly: return "Icon only"
            case .iconAndPercent: return "Icon + percentage"
            case .compact: return "Per provider"
            }
        }
    }

    /// Providers the user has explicitly turned off (everything else is enabled).
    var disabledProviders: Set<ProviderID>
    /// Global poll cadence; per-provider minimums still apply (Claude is clamped up).
    var pollIntervalSeconds: Int
    var menuBarDisplay: MenuBarDisplay
    /// Notify when a usage window crosses ~90%.
    var notificationsEnabled: Bool

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let disabled = "disabledProviders"
        static let interval = "pollIntervalSeconds"
        static let display = "menuBarDisplay"
        static let notifications = "notificationsEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedDisabled = (defaults.array(forKey: Key.disabled) as? [String]) ?? []
        self.disabledProviders = Set(storedDisabled.map { ProviderID(rawValue: $0) })
        let storedInterval = defaults.integer(forKey: Key.interval)
        self.pollIntervalSeconds = storedInterval > 0 ? storedInterval : 300
        self.menuBarDisplay = (defaults.string(forKey: Key.display)).flatMap(MenuBarDisplay.init(rawValue:)) ?? .iconAndPercent
        self.notificationsEnabled = (defaults.object(forKey: Key.notifications) as? Bool) ?? true
    }

    func isEnabled(_ id: ProviderID) -> Bool { !disabledProviders.contains(id) }

    func setEnabled(_ enabled: Bool, for id: ProviderID) {
        if enabled { disabledProviders.remove(id) } else { disabledProviders.insert(id) }
        save()
    }

    func save() {
        defaults.set(disabledProviders.map(\.rawValue), forKey: Key.disabled)
        defaults.set(pollIntervalSeconds, forKey: Key.interval)
        defaults.set(menuBarDisplay.rawValue, forKey: Key.display)
        defaults.set(notificationsEnabled, forKey: Key.notifications)
    }
}
