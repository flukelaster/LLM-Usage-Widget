using System.Text;
using System.Text.Json;
using LLMUsageWidget.Core.Auth;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Net;

namespace LLMUsageWidget.Core.Providers;

/// <summary>Claude (Anthropic) OAuth via the Claude Code public client. Paste-the-code flow: the
/// browser shows a <c>code#state</c> string the user pastes back (Anthropic rejects loopback redirects).</summary>
public sealed class ClaudeOAuthClient
{
    public const string ClientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e";
    public const string AuthorizeBase = "https://claude.ai/oauth/authorize";
    public const string TokenUrl = "https://console.anthropic.com/v1/oauth/token";
    public const string RedirectUri = "https://console.anthropic.com/oauth/code/callback";
    public const string Scopes = "org:create_api_key user:profile user:inference";

    public Uri MakeAuthorizeUrl(PkceChallenge pkce)
    {
        string q = Http.FormEncode(new Dictionary<string, string>
        {
            ["code"] = "true", ["client_id"] = ClientId, ["response_type"] = "code",
            ["redirect_uri"] = RedirectUri, ["scope"] = Scopes,
            ["code_challenge"] = pkce.Challenge, ["code_challenge_method"] = "S256", ["state"] = pkce.State
        });
        return new Uri($"{AuthorizeBase}?{q}");
    }

    /// <summary>Exchange the pasted "code#state" string for tokens.</summary>
    public async Task<OAuthToken> ExchangeAsync(string pastedCode, PkceChallenge pkce)
    {
        string[] parts = pastedCode.Trim().Split('#', 2);
        string code = parts.Length > 0 ? parts[0] : "";
        string returnedState = parts.Length > 1 ? parts[1] : "";
        if (string.IsNullOrEmpty(code)) throw ProviderException.Unauthorized();

        var body = new Dictionary<string, object?>
        {
            ["grant_type"] = "authorization_code", ["code"] = code,
            ["state"] = string.IsNullOrEmpty(returnedState) ? pkce.State : returnedState,
            ["client_id"] = ClientId, ["redirect_uri"] = RedirectUri, ["code_verifier"] = pkce.Verifier
        };
        return MakeToken(await PostJsonAsync(body), null);
    }

    public async Task<OAuthToken> RefreshAsync(OAuthToken token)
    {
        if (token.RefreshToken is null) throw ProviderException.Unauthorized();
        var body = new Dictionary<string, object?>
        {
            ["grant_type"] = "refresh_token", ["refresh_token"] = token.RefreshToken, ["client_id"] = ClientId
        };
        return MakeToken(await PostJsonAsync(body), token.RefreshToken);
    }

    private static async Task<OAuthTokenResponse> PostJsonAsync(Dictionary<string, object?> body)
    {
        var req = new HttpRequestMessage(HttpMethod.Post, TokenUrl);
        req.Headers.TryAddWithoutValidation("Accept", "application/json");
        req.Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");
        byte[] bytes = await Http.PostAsync(req);
        return JsonSerializer.Deserialize<OAuthTokenResponse>(bytes) ?? throw ProviderException.Decoding("token response");
    }

    private static OAuthToken MakeToken(OAuthTokenResponse r, string? previousRefresh) =>
        new(r.AccessToken, r.RefreshToken ?? previousRefresh, DateTimeOffset.UtcNow.AddSeconds(r.ExpiresIn ?? 3600));
}
