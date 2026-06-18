#if DEBUG
import Foundation
import CryptoKit
import SwiftUI

/// Lightweight in-process test suite, runnable without Xcode via `UsageWidget --check`.
/// Returns the number of failed checks (0 = all passed) for the process exit code.
@MainActor
func runSelfChecks() -> Int {
    var failures = 0
    func check(_ name: String, _ condition: Bool) {
        if condition {
            print("  ok   \(name)")
        } else {
            print("  FAIL \(name)")
            failures += 1
        }
    }
    func checkThrows(_ name: String, _ body: () throws -> Void) {
        do { try body(); check(name, false) } catch { check(name, true) }
    }

    print("== Usage mapping ==")
    do {
        let json = """
        {"five_hour":{"utilization":47.0,"resets_at":"2026-06-18T20:30:00Z"},
         "seven_day":{"utilization":63.0,"resets_at":"2026-06-21T09:00:00Z"},
         "seven_day_opus":{"utilization":71.0,"resets_at":"2026-06-21T09:00:00Z"},
         "seven_day_sonnet":{"utilization":40.0,"resets_at":"2026-06-21T09:00:00Z"}}
        """
        let usage = try ClaudeUsageFetcher.parse(Data(json.utf8))
        check("claude five_hour=47%", usage.fiveHour?.percent == 47)
        check("claude weekly=63%", usage.weekly?.percent == 63)
        check("claude hero windows=2", usage.heroWindows.count == 2)
        check("claude detail windows=2", usage.detailWindows.count == 2)
        check("claude resets parsed", usage.fiveHour?.resetsAt != nil)
        check("claude maxUtilization=0.71", abs(usage.maxUtilization - 0.71) < 0.001)
    } catch { check("claude parse threw: \(error)", false) }

    do {
        let json = #"{"five_hour":{"utilization":10.0,"resets_at":"2026-06-18T20:30:00.123Z"}}"#
        let usage = try ClaudeUsageFetcher.parse(Data(json.utf8))
        check("claude fractional seconds parsed", usage.fiveHour?.resetsAt != nil)
    } catch { check("claude fractional threw", false) }

    do {
        let json = """
        {"rate_limits":{"primary":{"used_percent":88.0,"window_minutes":300,"resets_at":1781000000},
         "secondary":{"used_percent":93.0,"window_minutes":10080,"resets_at":1781500000},"plan_type":"pro"}}
        """
        let usage = try CodexUsageFetcher.parse(Data(json.utf8), planFallback: nil)
        check("codex five_hour=88%", usage.fiveHour?.percent == 88)
        check("codex weekly=93%", usage.weekly?.percent == 93)
        check("codex plan=Pro", usage.plan?.displayName == "Pro")
    } catch { check("codex parse threw", false) }

    do {
        // Drifted field names: rate_limit / *_window / reset_at, plan at top level.
        let json = """
        {"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":12.0,"reset_at":1781000000},
         "secondary_window":{"used_percent":27.0,"reset_at":1781500000}}}
        """
        let usage = try CodexUsageFetcher.parse(Data(json.utf8), planFallback: nil)
        check("codex drift five_hour=12%", usage.fiveHour?.percent == 12)
        check("codex drift weekly=27%", usage.weekly?.percent == 27)
        check("codex drift plan=Plus", usage.plan?.displayName == "Plus")
    } catch { check("codex drift threw", false) }

    do {
        let usage = try CodexUsageFetcher.parse(Data(#"{"rate_limits":{"primary":{"used_percent":5.0}}}"#.utf8), planFallback: "team")
        check("codex plan fallback=Team", usage.plan?.displayName == "Team")
        check("codex single window", usage.weekly == nil && usage.fiveHour?.percent == 5)
    } catch { check("codex fallback threw", false) }

    checkThrows("codex empty {} throws") { _ = try CodexUsageFetcher.parse(Data("{}".utf8), planFallback: nil) }
    checkThrows("claude empty {} throws") { _ = try ClaudeUsageFetcher.parse(Data("{}".utf8)) }

    print("== Auth (PKCE / JWT / URLs) ==")
    let pkce = PKCE.generate()
    check("pkce verifier length=43", pkce.verifier.count == 43)
    check("pkce verifier url-safe", !pkce.verifier.contains("=") && !pkce.verifier.contains("+") && !pkce.verifier.contains("/"))
    check("pkce challenge == base64url(sha256(verifier))",
          pkce.challenge == PKCE.base64URL(Data(SHA256.hash(data: Data(pkce.verifier.utf8)))))
    check("pkce state unique", PKCE.generate().state != PKCE.generate().state)

    let jwt = "h.\(base64urlString(#"{"https://api.openai.com/auth":{"chatgpt_account_id":"acct_123","chatgpt_plan_type":"pro"}}"#)).s"
    let claims = CodexOAuthClient.decodeClaims(jwt: jwt)
    check("codex claims account id", claims.accountId == "acct_123")
    check("codex claims plan type", claims.planType == "pro")
    let topLevel = CodexOAuthClient.decodeClaims(jwt: "h.\(base64urlString(#"{"chatgpt_account_id":"acct_top"}"#)).s")
    check("codex claims top-level fallback", topLevel.accountId == "acct_top")
    check("codex claims malformed -> nil", CodexOAuthClient.decodeClaims(jwt: "nope").accountId == nil)

    let claudeURL = ClaudeOAuthClient().makeAuthorizeURL(pkce: pkce)
    let claudeItems = URLComponents(url: claudeURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
    check("claude authorize host", claudeURL.absoluteString.hasPrefix("https://claude.ai/oauth/authorize"))
    check("claude client_id", claudeItems.first { $0.name == "client_id" }?.value == "9d1c250a-e61b-44d9-88ed-5944d1962f5e")
    check("claude code=true", claudeItems.first { $0.name == "code" }?.value == "true")

    let codexURL = CodexOAuthClient().makeAuthorizeURL(pkce: pkce)
    let codexItems = URLComponents(url: codexURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
    check("codex authorize host", codexURL.absoluteString.hasPrefix("https://auth.openai.com/oauth/authorize"))
    check("codex client_id", codexItems.first { $0.name == "client_id" }?.value == "app_EMoamEEZ73f0CkXaXp7hrann")
    check("codex redirect_uri", codexItems.first { $0.name == "redirect_uri" }?.value == "http://localhost:1455/auth/callback")

    print("== Engine ==")
    var policy = BackoffPolicy(base: 60, maxDelay: 1800)
    check("backoff not active initially", !policy.isBackingOff)
    let d1 = policy.nextDelay(retryAfter: nil)
    check("backoff first 60...75", d1 >= 60 && d1 <= 75)
    let d2 = policy.nextDelay(retryAfter: nil)
    check("backoff second >=120", d2 >= 120)
    check("backoff honors retry-after", policy.nextDelay(retryAfter: 42) == 42)
    policy.reset()
    check("backoff reset", !policy.isBackingOff)

    check("limit clamp high", LimitWindow(kind: .fiveHour, utilization: 1.5, resetsAt: nil).percent == 100)
    check("limit clamp low", LimitWindow(kind: .fiveHour, utilization: -0.2, resetsAt: nil).percent == 0)
    check("threshold <0.60 safe", Theme.threshold(0.59) == Theme.safe)
    check("threshold 0.60 warn", Theme.threshold(0.60) == Theme.warn)
    check("threshold 0.85 high", Theme.threshold(0.85) == Theme.high)

    // Cache Codable round-trip (same path SnapshotCache uses).
    do {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let usage = ProviderUsage(providerID: .codex, plan: PlanInfo(displayName: "Pro", rawValue: "pro"),
                                  windows: [LimitWindow(kind: .fiveHour, utilization: 0.5, resetsAt: Date(timeIntervalSince1970: 1_781_000_000))])
        let data = try enc.encode(["codex": usage])
        let back = try dec.decode([String: ProviderUsage].self, from: data)
        check("cache round-trip", back["codex"]?.fiveHour?.percent == 50 && back["codex"]?.plan?.displayName == "Pro")
    } catch { check("cache round-trip threw", false) }

    print("== Formatting ==")
    let base = Date(timeIntervalSince1970: 1_000_000)
    check("countdown 2h 14m", RelativeTime.countdown(to: base.addingTimeInterval(2 * 3600 + 14 * 60), from: base) == "2h 14m")
    check("countdown 3d 5h", RelativeTime.countdown(to: base.addingTimeInterval(3 * 86400 + 5 * 3600), from: base) == "3d 5h")
    check("countdown now", RelativeTime.countdown(to: base, from: base) == "now")
    check("reset near", RelativeTime.resetLabel(base.addingTimeInterval(2 * 3600), from: base) == "resets in 2h")
    check("updated just now", RelativeTime.updatedAgo(base.addingTimeInterval(-5), from: base) == "updated just now")
    check("updated 2h ago", RelativeTime.updatedAgo(base.addingTimeInterval(-7200), from: base) == "updated 2h ago")
    check("number 1.28M", NumberFormat.compact(1_284_000) == "1.28M")
    check("number 4.1K", NumberFormat.compact(4_120) == "4.1K")
    check("currency", NumberFormat.currency(12.5) == "$12.50")

    print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) FAILED.")
    return failures
}

private func base64urlString(_ string: String) -> String {
    Data(string.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
#endif
