using System.Text;
using System.Text.Json;
using LLMUsageWidget.Core.Auth;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Net;

namespace LLMUsageWidget.Core.Providers;

/// <summary>GitHub Copilot OAuth via the device flow (the same client the editors use): show a short
/// user code, the user enters it at github.com/login/device, then poll for the token. The Copilot
/// usage endpoint accepts the plain GitHub user token (no JWT exchange).</summary>
public sealed class CopilotOAuthClient
{
    public const string ClientId = "Iv1.b507a08c87ecfe98";
    public const string DeviceCodeUrl = "https://github.com/login/device/code";
    public const string TokenUrl = "https://github.com/login/oauth/access_token";
    public const string DeviceGrant = "urn:ietf:params:oauth:grant-type:device_code";

    public sealed record DeviceCodeInfo(string DeviceCode, string UserCode, string VerificationUri, int ExpiresIn, int Interval);

    public async Task<DeviceCodeInfo> RequestDeviceCodeAsync()
    {
        var req = new HttpRequestMessage(HttpMethod.Post, DeviceCodeUrl)
        { Content = new StringContent($"client_id={ClientId}", Encoding.UTF8, "application/x-www-form-urlencoded") };
        req.Headers.TryAddWithoutValidation("Accept", "application/json");
        using var doc = JsonDocument.Parse(await Http.PostAsync(req));
        var r = doc.RootElement;
        return new DeviceCodeInfo(
            r.GetProperty("device_code").GetString()!,
            r.GetProperty("user_code").GetString()!,
            r.TryGetProperty("verification_uri", out var v) ? v.GetString()! : "https://github.com/login/device",
            r.TryGetProperty("expires_in", out var e) ? e.GetInt32() : 900,
            r.TryGetProperty("interval", out var i) ? i.GetInt32() : 5);
    }

    /// <summary>Poll until the user authorizes, honoring the server's interval / slow_down, until expiry.</summary>
    public async Task<OAuthToken> PollForTokenAsync(string deviceCode, int interval, int expiresIn, CancellationToken ct = default)
    {
        int delay = Math.Max(interval, 5), elapsed = 0;
        while (elapsed < expiresIn)
        {
            await Task.Delay(TimeSpan.FromSeconds(delay), ct);
            elapsed += delay;
            var (token, error) = await PollOnceAsync(deviceCode);
            if (token is not null) return token;
            if (error == "slow_down") delay += 5;
            else if (error == "authorization_pending") continue;
            else throw ProviderException.Transport(error ?? "device flow failed");
        }
        throw ProviderException.Transport("device flow timed out");
    }

    public async Task<OAuthToken> RefreshAsync(OAuthToken token)
    {
        if (token.RefreshToken is null) throw ProviderException.Unauthorized();
        var (newToken, _) = await PostFormAsync($"client_id={ClientId}&grant_type=refresh_token&refresh_token={token.RefreshToken}", token.RefreshToken);
        return newToken ?? throw ProviderException.Unauthorized();
    }

    private Task<(OAuthToken? Token, string? Error)> PollOnceAsync(string deviceCode) =>
        PostFormAsync($"client_id={ClientId}&device_code={deviceCode}&grant_type={DeviceGrant}", null);

    private static async Task<(OAuthToken? Token, string? Error)> PostFormAsync(string body, string? previousRefresh)
    {
        var req = new HttpRequestMessage(HttpMethod.Post, TokenUrl)
        { Content = new StringContent(body, Encoding.UTF8, "application/x-www-form-urlencoded") };
        req.Headers.TryAddWithoutValidation("Accept", "application/json");
        using var doc = JsonDocument.Parse(await Http.PostAsync(req));
        var r = doc.RootElement;
        if (r.TryGetProperty("access_token", out var at) && at.ValueKind == JsonValueKind.String)
        {
            double? exp = r.TryGetProperty("expires_in", out var e) && e.ValueKind == JsonValueKind.Number ? e.GetDouble() : null;
            string? refresh = r.TryGetProperty("refresh_token", out var rt) && rt.ValueKind == JsonValueKind.String ? rt.GetString() : previousRefresh;
            return (new OAuthToken(at.GetString()!, refresh, exp is double s ? DateTimeOffset.UtcNow.AddSeconds(s) : null), null);
        }
        string? error = r.TryGetProperty("error", out var er) && er.ValueKind == JsonValueKind.String ? er.GetString() : null;
        return (null, error);
    }
}
