using System.Text.Json;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Support;

namespace LLMUsageWidget.Core.Providers;

/// <summary>Maps the GitHub Copilot <c>copilot_internal/user</c> response into a monthly
/// premium-request quota window. Decoded leniently because the shape shifts across plans.</summary>
public static class CopilotUsageParser
{
    public static ProviderUsage Parse(byte[] data)
    {
        JsonDocument doc;
        try { doc = JsonDocument.Parse(data); }
        catch (Exception e) { throw ProviderException.Decoding("Non-JSON Copilot response: " + e.Message); }

        using (doc)
        {
            JsonElement root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) throw ProviderException.Decoding("Non-JSON Copilot response");

            string? plan = JsonX.Str(root, "copilot_plan");
            DateTimeOffset? reset = DateParse.Iso(JsonX.Str(root, "quota_reset_date_utc") ?? JsonX.Str(root, "quota_reset_date"));

            LimitWindow window;
            if (JsonX.TryObj(root, "quota_snapshots", out var snapshots) &&
                JsonX.TryObj(snapshots, "premium_interactions", out var premium))
            {
                bool unlimited = JsonX.Bool(premium, "unlimited") ?? false;
                if (unlimited)
                {
                    window = new LimitWindow(LimitWindowKind.Monthly, 0, reset, "Premium requests", Unlimited: true);
                }
                else
                {
                    double entitlement = JsonX.Num(premium, "entitlement") ?? 0;
                    double remaining = JsonX.Num(premium, "remaining") ?? JsonX.Num(premium, "quota_remaining") ?? 0;
                    double util = JsonX.Num(premium, "percent_remaining") is double pr
                        ? 1 - pr / 100
                        : (entitlement > 0 ? 1 - remaining / entitlement : 0);
                    window = new LimitWindow(LimitWindowKind.Monthly, util, reset, "Premium requests",
                        Used: Math.Max(0, entitlement - remaining), Limit: entitlement);
                }
            }
            else
            {
                // Unknown / credits-based plan — show as uncapped rather than failing.
                window = new LimitWindow(LimitWindowKind.Monthly, 0, reset, "Premium requests", Unlimited: true);
            }

            return new ProviderUsage(ProviderId.Copilot, new[] { window }, PlanInfo.From(plan), null, DateTimeOffset.UtcNow);
        }
    }
}
