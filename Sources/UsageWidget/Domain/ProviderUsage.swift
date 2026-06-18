import Foundation

/// A single snapshot of a provider's usage, returned by `UsageProvider.fetchUsage()`
/// and cached to disk. This is the unified currency the whole app speaks in.
struct ProviderUsage: Hashable, Codable, Sendable {
    let providerID: ProviderID
    var plan: PlanInfo?
    var windows: [LimitWindow]
    var tokens: TokenStats?
    /// When the provider produced this data (used for "updated 3m ago" / staleness).
    var capturedAt: Date

    init(
        providerID: ProviderID,
        plan: PlanInfo? = nil,
        windows: [LimitWindow],
        tokens: TokenStats? = nil,
        capturedAt: Date = Date()
    ) {
        self.providerID = providerID
        self.plan = plan
        self.windows = windows
        self.tokens = tokens
        self.capturedAt = capturedAt
    }

    /// The two windows that drive the hero view, ordered (5-hour first), each present at most once.
    var heroWindows: [LimitWindow] {
        windows.filter { $0.kind.isHero }.sorted { $0.kind.sortIndex < $1.kind.sortIndex }
    }

    /// Non-hero windows (e.g. per-model weekly breakdowns) shown under "Details".
    var detailWindows: [LimitWindow] {
        windows.filter { !$0.kind.isHero }.sorted { $0.kind.sortIndex < $1.kind.sortIndex }
    }

    var fiveHour: LimitWindow? { windows.first { $0.kind == .fiveHour } }
    var weekly: LimitWindow? { windows.first { $0.kind == .weekly } }

    /// Highest utilization across all windows — feeds the menu-bar headline percentage.
    var maxUtilization: Double {
        windows.map(\.clampedUtilization).max() ?? 0
    }
}
