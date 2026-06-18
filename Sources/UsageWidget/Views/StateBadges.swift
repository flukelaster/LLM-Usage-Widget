import SwiftUI

/// A small status pill (colored dot + text) used in card headers and for error/stale states.
struct StatusChip: View {
    enum Kind {
        case ok, warn, error, neutral

        var color: Color {
            switch self {
            case .ok: return Theme.safe
            case .warn: return Theme.warn
            case .error: return Theme.high
            case .neutral: return Theme.textTertiary
            }
        }
    }

    let text: String
    let kind: Kind
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
            } else {
                Circle()
                    .fill(kind.color)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(kind == .neutral ? Theme.textTertiary : kind.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(kind.color.opacity(0.12))
        )
    }
}

/// The small plan badge ("Max", "Pro") shown next to a provider name.
struct PlanBadge: View {
    let plan: PlanInfo
    let accent: Color

    var body: some View {
        Text(plan.displayName.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.15))
            )
    }
}
