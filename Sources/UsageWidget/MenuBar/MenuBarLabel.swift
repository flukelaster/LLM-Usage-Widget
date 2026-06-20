import SwiftUI

/// The status-bar item. By default it focuses on the **provider closest to a limit** — showing its
/// brand mark plus that provider's %, threshold-colored — so a single glance answers "whose 94%?".
/// The user can pin a specific provider via Settings (`menuBarProvider`).
struct MenuBarLabel: View {
    @Environment(UsageStore.self) private var store
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        let focus = store.menuBarFocus(pinned: settings.menuBarProvider)
        switch settings.menuBarDisplay {
        case .iconOnly:
            Image(systemName: gaugeSymbol(for: focus?.fraction ?? 0))

        case .peakPercent:
            if let focus {
                Image(systemName: gaugeSymbol(for: focus.fraction))
                Text(percentText(focus.fraction))
                    .foregroundStyle(Theme.threshold(focus.fraction))
            } else {
                Image(systemName: gaugeSymbol(for: 0))
            }

        case .peakProvider:
            // Brand mark of the focused provider (rasterized to a template image, since the
            // menu bar can't render SwiftUI Shapes) + its %.
            if let focus {
                if let icon = BrandMenuBarIcon.templateImage(for: focus.id) {
                    Image(nsImage: icon)
                } else {
                    Image(systemName: gaugeSymbol(for: focus.fraction))
                }
                Text(percentText(focus.fraction))
            } else {
                Image(systemName: gaugeSymbol(for: 0))
            }
        }
    }

    private func percentText(_ fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))%"
    }

    private func gaugeSymbol(for fraction: Double) -> String {
        switch fraction {
        case ..<0.5: return "gauge.with.dots.needle.bottom.0percent"
        case ..<0.85: return "gauge.with.dots.needle.bottom.50percent"
        default: return "gauge.with.dots.needle.bottom.100percent"
        }
    }
}
