namespace LLMUsageWidget.Core.Auth;

/// <summary>The app's own stored OAuth credentials for a provider. Persisted in the OS credential
/// store only.</summary>
public sealed record OAuthToken(
    string AccessToken,
    string? RefreshToken = null,
    DateTimeOffset? ExpiresAt = null,
    string? AccountId = null,   // Codex: chatgpt_account_id (for the ChatGPT-Account-Id header)
    string? PlanType = null)    // cached plan_type (Codex JWT) / organization_type (Claude profile)
{
    public bool IsExpired => ExpiresAt is { } e && DateTimeOffset.UtcNow >= e;

    /// <summary>True when the access token is within <paramref name="skew"/> of expiry (default 5 min).</summary>
    public bool NeedsRefresh(TimeSpan? skew = null) =>
        ExpiresAt is { } e && DateTimeOffset.UtcNow >= e - (skew ?? TimeSpan.FromMinutes(5));
}
