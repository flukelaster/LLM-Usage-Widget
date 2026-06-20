using System.Text.Json;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Support;

namespace LLMUsageWidget.Core.Providers;

/// <summary>Maps the Claude <c>GET /api/oauth/usage</c> response into <see cref="ProviderUsage"/>.
/// Utilization is a 0–100 percentage; resets_at is ISO-8601. The endpoint carries no plan, so the
/// plan string (from the profile endpoint) is passed in.</summary>
public static class ClaudeUsageParser
{
    public static ProviderUsage Parse(byte[] data, string? plan = null)
    {
        JsonDocument doc;
        try { doc = JsonDocument.Parse(data); }
        catch (Exception e) { throw ProviderException.Decoding(e.Message); }

        using (doc)
        {
            JsonElement root = doc.RootElement;
            var windows = new List<LimitWindow>();

            void Add(string key, LimitWindowKind kind)
            {
                if (!JsonX.TryObj(root, key, out var el)) return;
                double? util = JsonX.Num(el, "utilization");
                if (util is not double u) return;
                windows.Add(new LimitWindow(kind, u / 100, DateParse.Iso(JsonX.Str(el, "resets_at"))));
            }

            Add("five_hour", LimitWindowKind.FiveHour);
            Add("seven_day", LimitWindowKind.Weekly);
            Add("seven_day_opus", LimitWindowKind.WeeklyOpus);
            Add("seven_day_sonnet", LimitWindowKind.WeeklySonnet);

            if (windows.Count == 0) throw ProviderException.Decoding("No usage windows in response");

            return new ProviderUsage(ProviderId.Claude, windows, PlanInfo.From(plan), null, DateTimeOffset.UtcNow);
        }
    }
}
