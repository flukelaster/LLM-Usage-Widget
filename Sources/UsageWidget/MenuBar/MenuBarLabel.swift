import SwiftUI

/// The status-bar item: a gauge icon plus (optionally) the highest current utilization across
/// enabled providers. Rendered as a template in the menu bar, so it stays legible in light/dark.
struct MenuBarLabel: View {
    @Environment(UsageStore.self) private var store
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        let fraction = store.headlineUtilization
        switch settings.menuBarDisplay {
        case .iconOnly:
            Image(systemName: icon(for: fraction))
        case .iconAndPercent:
            if store.anyEnabledSignedIn {
                Image(systemName: icon(for: fraction))
                Text(percentText(fraction))
            } else {
                Image(systemName: icon(for: fraction))
            }
        case .compact:
            Image(systemName: icon(for: fraction))
            Text(compactText())
        }
    }

    private func percentText(_ fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))%"
    }

    private func compactText() -> String {
        let parts = store.enabledProviders.compactMap { provider -> String? in
            guard let usage = store.state(for: provider.id).usage else { return nil }
            let initial = provider.displayName.prefix(1)
            return "\(initial) \(Int((usage.maxUtilization * 100).rounded()))%"
        }
        return parts.joined(separator: " · ")
    }

    private func icon(for fraction: Double) -> String {
        switch fraction {
        case ..<0.5: return "gauge.with.dots.needle.bottom.0percent"
        case ..<0.85: return "gauge.with.dots.needle.bottom.50percent"
        default: return "gauge.with.dots.needle.bottom.100percent"
        }
    }
}
