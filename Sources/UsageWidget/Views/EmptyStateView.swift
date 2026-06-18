import SwiftUI

/// Shown only when no providers are enabled at all. (When providers are enabled but signed out,
/// each card shows its own sign-in CTA, which is the normal onboarding path.)
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.textSecondary)
            Text("No providers enabled")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Enable Claude or Codex in Settings to see your real-time usage limits.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
    }
}
