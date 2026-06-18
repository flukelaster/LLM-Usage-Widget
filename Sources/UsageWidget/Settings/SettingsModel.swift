import Foundation
import Observation

/// User-facing settings, persisted to `UserDefaults`. `@Observable` so the UI and the menu-bar
/// label react to changes. Per-provider minimum poll intervals still apply (Claude is clamped up).
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

    var enabledProviders: Set<ProviderID>
    var pollIntervalSeconds: Int
    var menuBarDisplay: MenuBarDisplay

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let enabled = "enabledProviders"
        static let interval = "pollIntervalSeconds"
        static let display = "menuBarDisplay"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let stored = defaults.array(forKey: Key.enabled) as? [String], !stored.isEmpty {
            self.enabledProviders = Set(stored.map { ProviderID(rawValue: $0) })
        } else {
            self.enabledProviders = [.claude, .codex]
        }
        let storedInterval = defaults.integer(forKey: Key.interval)
        self.pollIntervalSeconds = storedInterval > 0 ? storedInterval : 300
        self.menuBarDisplay = (defaults.string(forKey: Key.display)).flatMap(MenuBarDisplay.init(rawValue:)) ?? .iconAndPercent
    }

    func isEnabled(_ id: ProviderID) -> Bool { enabledProviders.contains(id) }

    func setEnabled(_ enabled: Bool, for id: ProviderID) {
        if enabled { enabledProviders.insert(id) } else { enabledProviders.remove(id) }
        save()
    }

    func save() {
        defaults.set(enabledProviders.map(\.rawValue), forKey: Key.enabled)
        defaults.set(pollIntervalSeconds, forKey: Key.interval)
        defaults.set(menuBarDisplay.rawValue, forKey: Key.display)
    }
}
