import Foundation

/// A single usage window for a provider, normalized into a common shape.
///
/// Most providers report rolling windows (Claude/Codex: ~5-hour + weekly). Quota-style providers
/// (Copilot: monthly premium-request allotment) use `.monthly` and carry raw `used`/`limit` counts.
struct LimitWindow: Identifiable, Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case fiveHour
        case weekly
        case weeklyOpus
        case weeklySonnet
        case monthly

        /// Default human-facing title (a window may override via `label`).
        var title: String {
            switch self {
            case .fiveHour: return "5-hour"
            case .weekly: return "Weekly"
            case .weeklyOpus: return "Weekly · Opus"
            case .weeklySonnet: return "Weekly · Sonnet"
            case .monthly: return "Monthly"
            }
        }

        /// Windows that make up the hero view. Others fold into "Details".
        var isHero: Bool { self == .fiveHour || self == .weekly || self == .monthly }

        var sortIndex: Int {
            switch self {
            case .fiveHour: return 0
            case .monthly: return 1
            case .weekly: return 2
            case .weeklyOpus: return 3
            case .weeklySonnet: return 4
            }
        }
    }

    let kind: Kind
    /// Normalized fraction used, 0...1.
    let utilization: Double
    /// When this window rolls over. Optional because a provider may omit it.
    let resetsAt: Date?
    /// Overrides `kind.title` (e.g. "Premium requests").
    var label: String?
    /// Raw counts for quota-style windows (e.g. 173 of 1500 requests). Optional.
    var used: Double?
    var limit: Double?
    /// True for quotas with no cap (shown as "Unlimited" instead of a bar).
    var unlimited: Bool

    var id: Kind { kind }

    init(kind: Kind, utilization: Double, resetsAt: Date?, label: String? = nil, used: Double? = nil, limit: Double? = nil, unlimited: Bool = false) {
        self.kind = kind
        self.utilization = utilization
        self.resetsAt = resetsAt
        self.label = label
        self.used = used
        self.limit = limit
        self.unlimited = unlimited
    }

    var displayTitle: String { label ?? kind.title }

    /// Utilization clamped to a safe 0...1 for display math.
    var clampedUtilization: Double { min(max(utilization, 0), 1) }

    /// Integer percentage used, e.g. 47.
    var percent: Int { Int((clampedUtilization * 100).rounded()) }

    /// "173 / 1,500" when raw counts are present.
    var countText: String? {
        guard let used, let limit, limit > 0 else { return nil }
        return "\(NumberFormat.compact(Int(used.rounded()))) / \(NumberFormat.compact(Int(limit.rounded())))"
    }
}
