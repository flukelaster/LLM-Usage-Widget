import Foundation

/// Fetches GitHub Copilot quota from the undocumented `copilot_internal/user` endpoint (the one the
/// editors use). Returns a monthly premium-request quota; chat/completions are typically unlimited.
struct CopilotUsageFetcher: Sendable {
    static let usageURL = URL(string: "https://api.github.com/copilot_internal/user")!

    func fetch(accessToken: String) async throws -> ProviderUsage {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("token \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("LLMUsageWidget", forHTTPHeaderField: "User-Agent")  // GitHub requires a UA
        let data = try await UsageHTTP.get(request)
        return try Self.parse(data)
    }

    /// Pure JSON → `ProviderUsage` mapping (no network). Decoded leniently because the shape shifts
    /// across plans / billing modes.
    static func parse(_ data: Data) throws -> ProviderUsage {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.decoding("Non-JSON Copilot response")
        }
        let plan = json["copilot_plan"] as? String
        let reset = parseDate((json["quota_reset_date_utc"] as? String) ?? (json["quota_reset_date"] as? String))

        var window: LimitWindow
        if let snapshots = json["quota_snapshots"] as? [String: Any],
           let premium = snapshots["premium_interactions"] as? [String: Any] {
            let unlimited = (premium["unlimited"] as? Bool) ?? false
            if unlimited {
                window = LimitWindow(kind: .monthly, utilization: 0, resetsAt: reset, label: "Premium requests", unlimited: true)
            } else {
                let entitlement = doubleValue(premium["entitlement"]) ?? 0
                let remaining = doubleValue(premium["remaining"]) ?? doubleValue(premium["quota_remaining"]) ?? 0
                let util: Double
                if let percentRemaining = doubleValue(premium["percent_remaining"]) {
                    util = 1 - percentRemaining / 100
                } else {
                    util = entitlement > 0 ? 1 - remaining / entitlement : 0
                }
                window = LimitWindow(kind: .monthly, utilization: util, resetsAt: reset,
                                     label: "Premium requests", used: max(0, entitlement - remaining), limit: entitlement)
            }
        } else {
            // Unknown / credits-based plan — show as uncapped rather than failing.
            window = LimitWindow(kind: .monthly, utilization: 0, resetsAt: reset, label: "Premium requests", unlimited: true)
        }

        return ProviderUsage(providerID: .copilot, plan: PlanInfo.from(rawPlanType: plan),
                             windows: [window], tokens: nil, capturedAt: Date())
    }

    private static func doubleValue(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        return nil
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        if let date = ISO8601DateFormatter().date(from: string) { return date }
        let dayOnly = DateFormatter()
        dayOnly.dateFormat = "yyyy-MM-dd"
        dayOnly.timeZone = TimeZone(identifier: "UTC")
        return dayOnly.date(from: string)
    }
}
