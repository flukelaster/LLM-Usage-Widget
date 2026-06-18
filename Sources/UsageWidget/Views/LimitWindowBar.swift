import SwiftUI

/// One usage window: label + big percentage on top, a capsule progress bar, and a reset countdown
/// (plus a raw "N / M" count for quota-style windows). Threshold-colored green → amber → red.
struct LimitWindowBar: View {
    let window: LimitWindow

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let fraction = window.clampedUtilization
        let color = Theme.threshold(fraction)

        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.displayTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if window.unlimited {
                    HStack(spacing: 3) {
                        Image(systemName: "infinity")
                        Text("Unlimited")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.safe)
                } else {
                    Text("\(window.percent)%")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                }
            }

            if window.unlimited {
                Capsule(style: .continuous).fill(Theme.barTrack).frame(height: Theme.barHeight)
            } else {
                track(fraction: fraction, color: color)
            }

            HStack(spacing: 6) {
                CountdownText(resetsAt: window.resetsAt)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
                if let countText = window.countText, !window.unlimited {
                    Text("·").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                    Text(countText).font(.system(size: 11)).monospacedDigit().foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(window.displayTitle) usage")
        .accessibilityValue(window.unlimited ? "Unlimited" : "\(window.percent) percent used, \(RelativeTime.resetLabel(window.resetsAt))")
    }

    private func track(fraction: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Theme.barTrack)
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.85), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(Theme.barHeight, geo.size.width * fraction))
                    .shadow(color: color.opacity(reduceMotion ? 0 : 0.45), radius: 4, y: 0)
            }
        }
        .frame(height: Theme.barHeight)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: fraction)
    }
}
