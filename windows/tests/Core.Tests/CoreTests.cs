using System.Text;
using LLMUsageWidget.Core.Auth;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Engine;
using LLMUsageWidget.Core.Providers;
using LLMUsageWidget.Core.Support;
using Xunit;

namespace LLMUsageWidget.Core.Tests;

/// <summary>Port of the Swift in-process self-checks (Diagnostics/SelfChecks.swift) — same fixtures,
/// same expected values — so the C# parsers/logic are verified to match the macOS app's behavior.</summary>
public class CoreTests
{
    private static byte[] B(string s) => Encoding.UTF8.GetBytes(s);

    private static string Base64Url(string s) =>
        Convert.ToBase64String(Encoding.UTF8.GetBytes(s)).Replace('+', '-').Replace('/', '_').TrimEnd('=');

    // MARK: - Claude usage mapping

    [Fact]
    public void Claude_UsageMapping()
    {
        var usage = ClaudeUsageParser.Parse(B("""
        {"five_hour":{"utilization":47.0,"resets_at":"2026-06-18T20:30:00Z"},
         "seven_day":{"utilization":63.0,"resets_at":"2026-06-21T09:00:00Z"},
         "seven_day_opus":{"utilization":71.0,"resets_at":"2026-06-21T09:00:00Z"},
         "seven_day_sonnet":{"utilization":40.0,"resets_at":"2026-06-21T09:00:00Z"}}
        """));
        Assert.Equal(47, usage.FiveHour!.Percent);
        Assert.Equal(63, usage.Weekly!.Percent);
        Assert.Equal(2, usage.HeroWindows.Count);
        Assert.Equal(2, usage.DetailWindows.Count);
        Assert.NotNull(usage.FiveHour!.ResetsAt);
        Assert.True(Math.Abs(usage.MaxUtilization - 0.71) < 0.001);
    }

    [Fact]
    public void Claude_FractionalSeconds()
    {
        var usage = ClaudeUsageParser.Parse(B("""{"five_hour":{"utilization":10.0,"resets_at":"2026-06-18T20:30:00.123Z"}}"""));
        Assert.NotNull(usage.FiveHour!.ResetsAt);
    }

    [Fact]
    public void Claude_ProfilePlan_And_Badge()
    {
        Assert.Equal("claude_max", ClaudeProfileParser.ParsePlan(
            B("""{"account":{"has_claude_max":true,"has_claude_pro":false},"organization":{"organization_type":"claude_max"}}""")));
        Assert.Equal("claude_pro", ClaudeProfileParser.ParsePlan(
            B("""{"account":{"has_claude_max":false,"has_claude_pro":true},"organization":{"organization_type":null}}""")));
        Assert.Null(ClaudeProfileParser.ParsePlan(B("{}")));

        var usage = ClaudeUsageParser.Parse(B("""{"five_hour":{"utilization":2.0}}"""), plan: "claude_max");
        Assert.Equal("Max", usage.Plan!.DisplayName);
        Assert.Equal("Pro", PlanInfo.From("claude_pro")!.DisplayName);
    }

    [Fact]
    public void Claude_Empty_Throws() =>
        Assert.Throws<ProviderException>(() => ClaudeUsageParser.Parse(B("{}")));

    // MARK: - Codex

    [Fact]
    public void Codex_UsageMapping()
    {
        var usage = CodexUsageParser.Parse(B("""
        {"rate_limits":{"primary":{"used_percent":88.0,"window_minutes":300,"resets_at":1781000000},
         "secondary":{"used_percent":93.0,"window_minutes":10080,"resets_at":1781500000},"plan_type":"pro"}}
        """), planFallback: null);
        Assert.Equal(88, usage.FiveHour!.Percent);
        Assert.Equal(93, usage.Weekly!.Percent);
        Assert.Equal("Pro", usage.Plan!.DisplayName);
    }

    [Fact]
    public void Codex_DriftedFieldNames()
    {
        var usage = CodexUsageParser.Parse(B("""
        {"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":12.0,"reset_at":1781000000},
         "secondary_window":{"used_percent":27.0,"reset_at":1781500000}}}
        """), planFallback: null);
        Assert.Equal(12, usage.FiveHour!.Percent);
        Assert.Equal(27, usage.Weekly!.Percent);
        Assert.Equal("Plus", usage.Plan!.DisplayName);
    }

    [Fact]
    public void Codex_PlanFallback_And_SingleWindow()
    {
        var usage = CodexUsageParser.Parse(B("""{"rate_limits":{"primary":{"used_percent":5.0}}}"""), planFallback: "team");
        Assert.Equal("Team", usage.Plan!.DisplayName);
        Assert.Null(usage.Weekly);
        Assert.Equal(5, usage.FiveHour!.Percent);
    }

    [Fact]
    public void Codex_Empty_Throws() =>
        Assert.Throws<ProviderException>(() => CodexUsageParser.Parse(B("{}"), planFallback: null));

    // MARK: - Copilot

    [Fact]
    public void Copilot_UsageMapping()
    {
        var usage = CopilotUsageParser.Parse(B("""
        {"copilot_plan":"individual_pro_plus","quota_reset_date_utc":"2026-02-01T00:00:00.000Z",
         "quota_snapshots":{"premium_interactions":{"entitlement":1500,"remaining":1327,"percent_remaining":88.5,"unlimited":false}}}
        """));
        var w = usage.HeroWindows[0];
        Assert.Equal(12, w.Percent);
        Assert.Equal("Pro+", usage.Plan!.DisplayName);
        Assert.Equal("173 / 1.5K", w.CountText);
        Assert.Equal(LimitWindowKind.Monthly, w.Kind);
    }

    [Fact]
    public void Copilot_Unlimited()
    {
        var usage = CopilotUsageParser.Parse(B("""{"copilot_plan":"business","quota_snapshots":{"premium_interactions":{"unlimited":true}}}"""));
        Assert.True(usage.HeroWindows[0].Unlimited);
    }

    // MARK: - Auth (PKCE / JWT)

    [Fact]
    public void Pkce_Generates_Valid_Challenge()
    {
        var pkce = Pkce.Generate();
        Assert.Equal(43, pkce.Verifier.Length);
        Assert.DoesNotContain('=', pkce.Verifier);
        Assert.DoesNotContain('+', pkce.Verifier);
        Assert.DoesNotContain('/', pkce.Verifier);
        var expected = Pkce.Base64Url(System.Security.Cryptography.SHA256.HashData(Encoding.UTF8.GetBytes(pkce.Verifier)));
        Assert.Equal(expected, pkce.Challenge);
        Assert.NotEqual(Pkce.Generate().State, Pkce.Generate().State);
    }

    [Fact]
    public void Codex_JwtClaims()
    {
        string payload = Base64Url("""{"https://api.openai.com/auth":{"chatgpt_account_id":"acct_123","chatgpt_plan_type":"pro"}}""");
        var claims = CodexClaims.Decode($"h.{payload}.s");
        Assert.Equal("acct_123", claims.AccountId);
        Assert.Equal("pro", claims.PlanType);

        var topLevel = CodexClaims.Decode($"h.{Base64Url("""{"chatgpt_account_id":"acct_top"}""")}.s");
        Assert.Equal("acct_top", topLevel.AccountId);

        Assert.Null(CodexClaims.Decode("nope").AccountId);
    }

    // MARK: - Engine

    [Fact]
    public void Backoff_GrowsAndHonorsRetryAfter()
    {
        var policy = new BackoffPolicy(baseSeconds: 60, maxSeconds: 1800);
        Assert.False(policy.IsBackingOff);
        double d1 = policy.NextDelaySeconds(null);
        Assert.InRange(d1, 60, 75);
        double d2 = policy.NextDelaySeconds(null);
        Assert.True(d2 >= 120);
        Assert.Equal(42, policy.NextDelaySeconds(42));
        policy.Reset();
        Assert.False(policy.IsBackingOff);
    }

    [Fact]
    public void Limit_Clamp_And_Threshold()
    {
        Assert.Equal(100, new LimitWindow(LimitWindowKind.FiveHour, 1.5, null).Percent);
        Assert.Equal(0, new LimitWindow(LimitWindowKind.FiveHour, -0.2, null).Percent);
        Assert.Equal(ThresholdLevel.Safe, UsageThreshold.Level(0.59));
        Assert.Equal(ThresholdLevel.Warn, UsageThreshold.Level(0.60));
        Assert.Equal(ThresholdLevel.High, UsageThreshold.Level(0.85));
    }

    // MARK: - Formatting

    [Fact]
    public void Formatting_Countdown_Reset_Updated_Numbers()
    {
        var b = DateTimeOffset.FromUnixTimeSeconds(1_000_000);
        Assert.Equal("2h 14m", RelativeTime.Countdown(b.AddSeconds(2 * 3600 + 14 * 60), b));
        Assert.Equal("3d 5h", RelativeTime.Countdown(b.AddSeconds(3 * 86400 + 5 * 3600), b));
        Assert.Equal("now", RelativeTime.Countdown(b, b));
        Assert.Equal("resets in 2h", RelativeTime.ResetLabel(b.AddSeconds(2 * 3600), b));
        Assert.Equal("updated just now", RelativeTime.UpdatedAgo(b.AddSeconds(-5), b));
        Assert.Equal("updated 2h ago", RelativeTime.UpdatedAgo(b.AddSeconds(-7200), b));
        Assert.Equal("1.28M", NumberFormat.Compact(1_284_000));
        Assert.Equal("4.1K", NumberFormat.Compact(4_120));
        Assert.Equal("$12.50", NumberFormat.Currency(12.5));
    }
}
