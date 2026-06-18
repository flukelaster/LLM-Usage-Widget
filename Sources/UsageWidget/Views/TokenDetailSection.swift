import SwiftUI

/// Collapsible secondary section: per-model weekly windows (Claude) and token/cost totals.
/// Hidden entirely when a provider exposes no detail data.
struct TokenDetailSection: View {
    let usage: ProviderUsage
    @State private var expanded = false

    private var hasDetail: Bool {
        (usage.tokens?.hasAnyValue ?? false) || !usage.detailWindows.isEmpty
    }

    var body: some View {
        if hasDetail {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                        Text("Details")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(usage.detailWindows) { window in
                            row(window.kind.title,
                                "\(window.percent)%",
                                valueColor: Theme.threshold(window.clampedUtilization))
                        }
                        if let tokens = usage.tokens {
                            if let total = tokens.totalTokens {
                                row("Tokens", NumberFormat.compact(total))
                            }
                            if let cost = tokens.estimatedCostUSD {
                                row("Est. cost", NumberFormat.currency(cost))
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private func row(_ label: String, _ value: String, valueColor: Color = Theme.textSecondary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
    }
}
