using System.Text.Json;

namespace LLMUsageWidget.Core.Providers;

/// <summary>Extracts the Claude subscription plan from <c>GET /api/oauth/profile</c>. The usage
/// endpoint has no plan field, so the Max / Pro badge comes from here. Prefers the organization's
/// <c>organization_type</c>, falling back to the account's <c>has_claude_*</c> booleans.</summary>
public static class ClaudeProfileParser
{
    /// <summary>Returns the raw plan string (e.g. "claude_max"), or null if it can't be determined.</summary>
    public static string? ParsePlan(byte[] data)
    {
        JsonDocument doc;
        try { doc = JsonDocument.Parse(data); }
        catch { return null; }

        using (doc)
        {
            JsonElement root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return null;

            if (JsonX.TryObj(root, "organization", out var org))
            {
                string? type = JsonX.Str(org, "organization_type");
                if (!string.IsNullOrWhiteSpace(type)) return type;
            }
            if (JsonX.TryObj(root, "account", out var account))
            {
                if (JsonX.Bool(account, "has_claude_max") == true) return "claude_max";
                if (JsonX.Bool(account, "has_claude_pro") == true) return "claude_pro";
            }
            return null;
        }
    }
}
