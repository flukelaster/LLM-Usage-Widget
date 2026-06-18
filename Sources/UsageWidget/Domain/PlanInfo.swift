import Foundation

/// Subscription plan info shown as a small badge on each provider card.
struct PlanInfo: Hashable, Codable, Sendable {
    let displayName: String   // "Max", "Pro", "Plus", "Team", "Enterprise"
    let rawValue: String?     // provider's raw plan_type, kept for debugging

    init(displayName: String, rawValue: String? = nil) {
        self.displayName = displayName
        self.rawValue = rawValue
    }

    /// Build a nicely-cased plan from a provider's raw `plan_type` string.
    static func from(rawPlanType raw: String?) -> PlanInfo? {
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let pretty: String
        switch raw.lowercased() {
        case "free": pretty = "Free"
        case "plus": pretty = "Plus"
        case "pro": pretty = "Pro"
        case "team": pretty = "Team"
        case "enterprise", "ent": pretty = "Enterprise"
        case "max", "max_5x", "max_20x", "max5x", "max20x": pretty = "Max"
        case "individual_pro_plus", "pro_plus": pretty = "Pro+"
        case "individual_pro": pretty = "Pro"
        case "individual": pretty = "Individual"
        case "business": pretty = "Business"
        default: pretty = raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return PlanInfo(displayName: pretty, rawValue: raw)
    }
}
