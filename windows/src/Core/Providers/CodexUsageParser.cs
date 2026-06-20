using System.Text.Json;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Support;

namespace LLMUsageWidget.Core.Providers;

/// <summary>Maps the Codex <c>GET /backend-api/wham/usage</c> response. Decoded tolerantly because
/// field names have drifted across versions (rate_limit(s), primary(_window), reset(s)_at).</summary>
public static class CodexUsageParser
{
    public static ProviderUsage Parse(byte[] data, string? planFallback = null)
    {
        JsonDocument doc;
        try { doc = JsonDocument.Parse(data); }
        catch (Exception e) { throw ProviderException.Decoding(e.Message); }

        using (doc)
        {
            JsonElement root = doc.RootElement;
            bool hasRl = JsonX.TryObj(root, "rate_limits", out var rl) || JsonX.TryObj(root, "rate_limit", out rl);

            var windows = new List<LimitWindow>();
            if (hasRl)
            {
                if (TryWindow(rl, "primary", "primary_window", out double pPct, out var pReset))
                    windows.Add(new LimitWindow(LimitWindowKind.FiveHour, pPct / 100, pReset));
                if (TryWindow(rl, "secondary", "secondary_window", out double sPct, out var sReset))
                    windows.Add(new LimitWindow(LimitWindowKind.Weekly, sPct / 100, sReset));
            }
            if (windows.Count == 0) throw ProviderException.Decoding("No rate-limit windows in response");

            string? rawPlan = JsonX.Str(root, "plan_type")
                              ?? (hasRl ? JsonX.Str(rl, "plan_type") : null)
                              ?? planFallback;

            return new ProviderUsage(ProviderId.Codex, windows, PlanInfo.From(rawPlan), null, DateTimeOffset.UtcNow);
        }
    }

    private static bool TryWindow(JsonElement parent, string a, string b, out double percent, out DateTimeOffset? reset)
    {
        percent = 0;
        reset = null;
        if (!JsonX.TryObj(parent, a, out var w) && !JsonX.TryObj(parent, b, out w)) return false;
        if (JsonX.Num(w, "used_percent") is not double up) return false;
        percent = up;
        double? epoch = JsonX.Num(w, "resets_at") ?? JsonX.Num(w, "reset_at");
        reset = epoch is double e ? DateParse.FromUnixSeconds(e) : null;
        return true;
    }
}
