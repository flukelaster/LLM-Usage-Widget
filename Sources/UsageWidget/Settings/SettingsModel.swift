import Foundation
import Observation

/// User-facing settings, persisted to `UserDefaults`. `@Observable` so the UI and the menu-bar
/// label react to changes. Providers are enabled-by-default: we store the *disabled* set, so a
/// newly-added provider shows up automatically instead of being hidden by an old persisted list.
@MainActor
@Observable
final class SettingsModel {
    /// How the menu-bar item is rendered. Orthogonal to *which* provider it focuses on
    /// (see `menuBarProvider`).
    enum MenuBarDisplay: String, CaseIterable, Codable, Sendable, Identifiable {
        /// Brand icon of the focused provider + its %. (Default — answers "whose 94%?")
        case peakProvider
        /// Gauge icon + the focused %, no brand icon.
        case peakPercent
        /// Gauge icon only.
        case iconOnly

        var id: String { rawValue }
        var title: String {
            switch self {
            case .peakProvider: return "Provider icon + %"
            case .peakPercent: return "Gauge + %"
            case .iconOnly: return "Icon only"
            }
        }
    }

    /// Providers the user has explicitly turned off (everything else is enabled).
    var disabledProviders: Set<ProviderID>
    /// Global poll cadence; per-provider minimums still apply (Claude is clamped up).
    var pollIntervalSeconds: Int
    var menuBarDisplay: MenuBarDisplay
    /// Which provider the menu bar focuses on. `nil` = whichever is closest to full (default).
    var menuBarProvider: ProviderID?
    /// Notify when a usage window crosses ~90%.
    var notificationsEnabled: Bool

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let disabled = "disabledProviders"
        static let interval = "pollIntervalSeconds"
        static let display = "menuBarDisplay"
        static let menuBarProvider = "menuBarProvider"
        static let notifications = "notificationsEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedDisabled = (defaults.array(forKey: Key.disabled) as? [String]) ?? []
        self.disabledProviders = Set(storedDisabled.map { ProviderID(rawValue: $0) })
        let storedInterval = defaults.integer(forKey: Key.interval)
        self.pollIntervalSeconds = storedInterval > 0 ? storedInterval : 300
        self.menuBarDisplay = (defaults.string(forKey: Key.display)).flatMap(MenuBarDisplay.init(rawValue:)) ?? .peakProvider
        self.menuBarProvider = defaults.string(forKey: Key.menuBarProvider).map(ProviderID.init(rawValue:))
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
        defaults.set(menuBarProvider?.rawValue, forKey: Key.menuBarProvider)
        defaults.set(notificationsEnabled, forKey: Key.notifications)
    }
}
