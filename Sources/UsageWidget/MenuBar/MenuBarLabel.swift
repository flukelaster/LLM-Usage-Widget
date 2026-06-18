import SwiftUI

/// The status-bar item. By default it focuses on the **provider closest to a limit** — showing its
/// brand mark plus that provider's %, threshold-colored — so a single glance answers "whose 94%?".
struct MenuBarLabel: View {
    @Environment(UsageStore.self) private var store
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        switch settings.menuBarDisplay {
        case .iconOnly:
            Image(systemName: gaugeSymbol(for: store.peakProvider?.fraction ?? 0))

        case .peakPercent:
            if let peak = store.peakProvider {
                Image(systemName: gaugeSymbol(for: peak.fraction))
                Text(percentText(peak.fraction))
                    .foregroundStyle(Theme.threshold(peak.fraction))
            } else {
                Image(systemName: gaugeSymbol(for: 0))
            }

        case .peakProvider:
            // Brand mark of the closest-to-full provider (rasterized to a template image, since the
            // menu bar can't render SwiftUI Shapes) + its %.
            if let peak = store.peakProvider {
                if let icon = BrandMenuBarIcon.templateImage(for: peak.id) {
                    Image(nsImage: icon)
                } else {
                    Image(systemName: gaugeSymbol(for: peak.fraction))
                }
                Text(percentText(peak.fraction))
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
