import Foundation

/// Raw shape of `GET /backend-api/wham/usage`, decoded tolerantly because field names have drifted
/// across versions (`rate_limit`/`rate_limits`, `primary`/`primary_window`, `reset_at`/`resets_at`).
private struct CodexUsageResponse: Decodable {
    struct Window: Decodable {
        let usedPercent: Double?
        let resetsAt: Double?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyCodingKey.self)
            usedPercent = (try? c.decode(Double.self, forKey: AnyCodingKey("used_percent")))
            resetsAt = (try? c.decode(Double.self, forKey: AnyCodingKey("resets_at")))
                ?? (try? c.decode(Double.self, forKey: AnyCodingKey("reset_at")))
        }
    }

    struct RateLimits: Decodable {
        let primary: Window?
        let secondary: Window?
        let planType: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyCodingKey.self)
            primary = (try? c.decode(Window.self, forKey: AnyCodingKey("primary")))
                ?? (try? c.decode(Window.self, forKey: AnyCodingKey("primary_window")))
            secondary = (try? c.decode(Window.self, forKey: AnyCodingKey("secondary")))
                ?? (try? c.decode(Window.self, forKey: AnyCodingKey("secondary_window")))
            planType = try? c.decode(String.self, forKey: AnyCodingKey("plan_type"))
        }
    }

    let rateLimits: RateLimits?
    let planType: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        rateLimits = (try? c.decode(RateLimits.self, forKey: AnyCodingKey("rate_limits")))
            ?? (try? c.decode(RateLimits.self, forKey: AnyCodingKey("rate_limit")))
        planType = try? c.decode(String.self, forKey: AnyCodingKey("plan_type"))
    }
}

struct CodexUsageFetcher: Sendable {
    static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    func fetch(accessToken: String, accountId: String?, planFallback: String?) async throws -> ProviderUsage {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("LLMUsageWidget", forHTTPHeaderField: "User-Agent")
        if let accountId {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let data = try await UsageHTTP.get(request)
        return try Self.parse(data, planFallback: planFallback)
    }

    /// Pure JSON → `ProviderUsage` mapping (no network), exposed for unit tests.
    static func parse(_ data: Data, planFallback: String?) throws -> ProviderUsage {
        let decoded: CodexUsageResponse
        do {
            decoded = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
        } catch {
            throw ProviderError.decoding(error.localizedDescription)
        }

        var windows: [LimitWindow] = []
        if let primary = decoded.rateLimits?.primary, let percent = primary.usedPercent {
            windows.append(LimitWindow(kind: .fiveHour, utilization: percent / 100, resetsAt: primary.resetsAt.map { Date(timeIntervalSince1970: $0) }))
        }
        if let secondary = decoded.rateLimits?.secondary, let percent = secondary.usedPercent {
            windows.append(LimitWindow(kind: .weekly, utilization: percent / 100, resetsAt: secondary.resetsAt.map { Date(timeIntervalSince1970: $0) }))
        }
        guard !windows.isEmpty else { throw ProviderError.decoding("No rate-limit windows in response") }

        let rawPlan = decoded.planType ?? decoded.rateLimits?.planType ?? planFallback
        return ProviderUsage(
            providerID: .codex,
            plan: PlanInfo.from(rawPlanType: rawPlan),
            windows: windows,
            tokens: nil,
            capturedAt: Date()
        )
    }
}
