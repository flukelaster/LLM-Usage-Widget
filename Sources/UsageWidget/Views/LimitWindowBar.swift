import SwiftUI

/// One usage window: label + big percentage on top, a capsule progress bar, and a reset countdown.
/// The percentage and fill are threshold-colored (green → amber → red).
struct LimitWindowBar: View {
    let window: LimitWindow

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let fraction = window.clampedUtilization
        let color = Theme.threshold(fraction)

        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.kind.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(window.percent)%")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }

            track(fraction: fraction, color: color)

            CountdownText(resetsAt: window.resetsAt)
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(window.kind.title) usage")
        .accessibilityValue("\(window.percent) percent used, \(RelativeTime.resetLabel(window.resetsAt))")
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
