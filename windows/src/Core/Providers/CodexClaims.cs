using System.Text.Json;

namespace LLMUsageWidget.Core.Providers;

/// <summary>Decodes <c>chatgpt_account_id</c> and <c>chatgpt_plan_type</c> from a Codex id_token JWT
/// payload (under the <c>https://api.openai.com/auth</c> claim, with a top-level fallback).</summary>
public static class CodexClaims
{
    public static (string? AccountId, string? PlanType) Decode(string jwt)
    {
        string[] segments = jwt.Split('.');
        if (segments.Length < 2) return (null, null);

        string b64 = segments[1].Replace('-', '+').Replace('_', '/');
        switch (b64.Length % 4)
        {
            case 2: b64 += "=="; break;
            case 3: b64 += "="; break;
        }

        byte[] bytes;
        try { bytes = Convert.FromBase64String(b64); }
        catch { return (null, null); }

        JsonDocument doc;
        try { doc = JsonDocument.Parse(bytes); }
        catch { return (null, null); }

        using (doc)
        {
            JsonElement root = doc.RootElement;
            string? accountId = null, planType = null;
            if (JsonX.TryObj(root, "https://api.openai.com/auth", out var auth))
            {
                accountId = JsonX.Str(auth, "chatgpt_account_id");
                planType = JsonX.Str(auth, "chatgpt_plan_type");
            }
            accountId ??= JsonX.Str(root, "chatgpt_account_id");
            planType ??= JsonX.Str(root, "chatgpt_plan_type");
            return (accountId, planType);
        }
    }
}
