import Foundation

/// A single rate-limit window for a provider, normalized into a common shape.
///
/// Both providers report a short rolling window (~5 hours) and a long window (~weekly).
/// Some providers (Claude) additionally break the weekly window down per model family.
struct LimitWindow: Identifiable, Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case fiveHour
        case weekly
        case weeklyOpus
        case weeklySonnet

        /// Short, human-facing title for the bar.
        var title: String {
            switch self {
            case .fiveHour: return "5-hour"
            case .weekly: return "Weekly"
            case .weeklyOpus: return "Weekly · Opus"
            case .weeklySonnet: return "Weekly · Sonnet"
            }
        }

        /// The two windows that make up the hero view. Others fold into "Details".
        var isHero: Bool { self == .fiveHour || self == .weekly }

        /// Sort order so `5-hour` is always shown above `Weekly`.
        var sortIndex: Int {
            switch self {
            case .fiveHour: return 0
            case .weekly: return 1
            case .weeklyOpus: return 2
            case .weeklySonnet: return 3
            }
        }
    }

    let kind: Kind
    /// Normalized fraction used, 0...1. Providers report 0-100 percentages; map by /100.
    let utilization: Double
    /// When this window rolls over. Optional because a provider may omit it.
    let resetsAt: Date?

    var id: Kind { kind }

    init(kind: Kind, utilization: Double, resetsAt: Date?) {
        self.kind = kind
        self.utilization = utilization
        self.resetsAt = resetsAt
    }

    /// Utilization clamped to a safe 0...1 for display math.
    var clampedUtilization: Double { min(max(utilization, 0), 1) }

    /// Integer percentage used, e.g. 47.
    var percent: Int { Int((clampedUtilization * 100).rounded()) }
}
