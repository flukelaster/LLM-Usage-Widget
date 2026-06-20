using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Net;

namespace LLMUsageWidget.Core.Providers;

/// <summary>HTTP usage fetchers — each adds the provider-specific headers its first-party client
/// uses, then hands the body to the matching pure parser.</summary>
public sealed class ClaudeUsageFetcher
{
    public const string UsageUrl = "https://api.anthropic.com/api/oauth/usage";
    public const string ClientVersion = "2.1.0";

    public async Task<ProviderUsage> FetchAsync(string accessToken, string? plan)
    {
        var req = new HttpRequestMessage(HttpMethod.Get, UsageUrl);
        req.Headers.TryAddWithoutValidation("Authorization", $"Bearer {accessToken}");
        req.Headers.TryAddWithoutValidation("Accept", "application/json");
        req.Headers.TryAddWithoutValidation("anthropic-beta", "oauth-2025-04-20");
        req.Headers.TryAddWithoutValidation("User-Agent", $"claude-code/{ClientVersion}");
        return ClaudeUsageParser.Parse(await Http.GetAsync(req), plan);
    }
}

/// <summary>Claude has no plan in its usage endpoint, so the badge comes from the profile endpoint.</summary>
public sealed class ClaudeProfileFetcher
{
    public const string ProfileUrl = "https://api.anthropic.com/api/oauth/profile";

    public async Task<string?> FetchRawPlanAsync(string accessToken)
    {
        var req = new HttpRequestMessage(HttpMethod.Get, ProfileUrl);
        req.Headers.TryAddWithoutValidation("Authorization", $"Bearer {accessToken}");
        req.Headers.TryAddWithoutValidation("Accept", "application/json");
        req.Headers.TryAddWithoutValidation("anthropic-beta", "oauth-2025-04-20");
        req.Headers.TryAddWithoutValidation("User-Agent", $"claude-code/{ClaudeUsageFetcher.ClientVersion}");
        return ClaudeProfileParser.ParsePlan(await Http.GetAsync(req));
    }
}

public sealed class CodexUsageFetcher
{
    public const string UsageUrl = "https://chatgpt.com/backend-api/wham/usage";

    public async Task<ProviderUsage> FetchAsync(string accessToken, string? accountId, string? planFallback)
    {
        var req = new HttpRequestMessage(HttpMethod.Get, UsageUrl);
        req.Headers.TryAddWithoutValidation("Authorization", $"Bearer {accessToken}");
        req.Headers.TryAddWithoutValidation("Accept", "application/json");
        req.Headers.TryAddWithoutValidation("User-Agent", "LLMUsageWidget");
        if (!string.IsNullOrEmpty(accountId))
            req.Headers.TryAddWithoutValidation("ChatGPT-Account-Id", accountId);
        return CodexUsageParser.Parse(await Http.GetAsync(req), planFallback);
    }
}

public sealed class CopilotUsageFetcher
{
    public const string UsageUrl = "https://api.github.com/copilot_internal/user";

    public async Task<ProviderUsage> FetchAsync(string accessToken)
    {
        var req = new HttpRequestMessage(HttpMethod.Get, UsageUrl);
        req.Headers.TryAddWithoutValidation("Authorization", $"token {accessToken}");
        req.Headers.TryAddWithoutValidation("Accept", "application/json");
        req.Headers.TryAddWithoutValidation("User-Agent", "LLMUsageWidget");  // GitHub requires a UA
        return CopilotUsageParser.Parse(await Http.GetAsync(req));
    }
}
