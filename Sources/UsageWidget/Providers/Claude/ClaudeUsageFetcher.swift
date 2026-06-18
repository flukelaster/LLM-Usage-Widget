import Foundation

/// Raw shape of `GET /api/oauth/usage` — utilization is a 0–100 percentage; resets_at is ISO-8601.
private struct ClaudeUsageResponse: Decodable {
    struct Window: Decodable {
        let utilization: Double?
        let resetsAt: String?
        enum CodingKeys: String, CodingKey { case utilization; case resetsAt = "resets_at" }
    }
    let fiveHour: Window?
    let sevenDay: Window?
    let sevenDayOpus: Window?
    let sevenDaySonnet: Window?
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
    }
}

/// Fetches Claude subscription usage. The `User-Agent: claude-code/<version>` header is REQUIRED —
/// without it the endpoint rate-limits aggressively. Version is configurable in case Anthropic
/// tightens UA validation.
struct ClaudeUsageFetcher: Sendable {
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let clientVersion = "2.1.0"

    func fetch(accessToken: String) async throws -> ProviderUsage {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/\(Self.clientVersion)", forHTTPHeaderField: "User-Agent")

        let data = try await UsageHTTP.get(request)
        return try Self.parse(data)
    }

    /// Pure JSON → `ProviderUsage` mapping (no network), exposed for unit tests.
    static func parse(_ data: Data) throws -> ProviderUsage {
        let decoded: ClaudeUsageResponse
        do {
            decoded = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
        } catch {
            throw ProviderError.decoding(error.localizedDescription)
        }
        let windows = map(decoded)
        guard !windows.isEmpty else { throw ProviderError.decoding("No usage windows in response") }
        return ProviderUsage(providerID: .claude, plan: nil, windows: windows, tokens: nil, capturedAt: Date())
    }

    private static func map(_ response: ClaudeUsageResponse) -> [LimitWindow] {
        func window(_ raw: ClaudeUsageResponse.Window?, _ kind: LimitWindow.Kind) -> LimitWindow? {
            guard let raw, let utilization = raw.utilization else { return nil }
            return LimitWindow(kind: kind, utilization: utilization / 100, resetsAt: parseDate(raw.resetsAt))
        }
        return [
            window(response.fiveHour, .fiveHour),
            window(response.sevenDay, .weekly),
            window(response.sevenDayOpus, .weeklyOpus),
            window(response.sevenDaySonnet, .weeklySonnet)
        ].compactMap { $0 }
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        return ISO8601DateFormatter().date(from: string)
    }
}
