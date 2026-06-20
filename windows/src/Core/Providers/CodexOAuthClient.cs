using System.Text;
using System.Text.Json;
using LLMUsageWidget.Core.Auth;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Net;

namespace LLMUsageWidget.Core.Providers;

/// <summary>Codex (OpenAI) OAuth via the public Codex CLI client. Loopback redirect on
/// 127.0.0.1:1455. Token exchange is form-urlencoded; refresh is JSON. The id_token JWT carries
/// chatgpt_account_id + chatgpt_plan_type.</summary>
public sealed class CodexOAuthClient
{
    public const string ClientId = "app_EMoamEEZ73f0CkXaXp7hrann";
    public const string AuthorizeBase = "https://auth.openai.com/oauth/authorize";
    public const string TokenUrl = "https://auth.openai.com/oauth/token";
    public const string RedirectUri = "http://localhost:1455/auth/callback";
    public const int LoopbackPort = 1455;
    public const string Scopes = "openid profile email offline_access";
    public const string Originator = "llm_usage_widget";

    public Uri MakeAuthorizeUrl(PkceChallenge pkce)
    {
        string q = Http.FormEncode(new Dictionary<string, string>
        {
            ["response_type"] = "code", ["client_id"] = ClientId, ["redirect_uri"] = RedirectUri,
            ["scope"] = Scopes, ["code_challenge"] = pkce.Challenge, ["code_challenge_method"] = "S256",
            ["id_token_add_organizations"] = "true", ["codex_cli_simplified_flow"] = "true",
            ["originator"] = Originator, ["state"] = pkce.State
        });
        return new Uri($"{AuthorizeBase}?{q}");
    }

    public async Task<OAuthToken> ExchangeAsync(string code, PkceChallenge pkce)
    {
        string form = Http.FormEncode(new Dictionary<string, string>
        {
            ["grant_type"] = "authorization_code", ["code"] = code, ["redirect_uri"] = RedirectUri,
            ["client_id"] = ClientId, ["code_verifier"] = pkce.Verifier
        });
        var req = new HttpRequestMessage(HttpMethod.Post, TokenUrl)
        { Content = new StringContent(form, Encoding.UTF8, "application/x-www-form-urlencoded") };
        return MakeToken(await PostJsonAsync(req), null, null);
    }

    public async Task<OAuthToken> RefreshAsync(OAuthToken token)
    {
        if (token.RefreshToken is null) throw ProviderException.Unauthorized();
        var body = new Dictionary<string, object?>
        {
            ["client_id"] = ClientId, ["grant_type"] = "refresh_token",
            ["refresh_token"] = token.RefreshToken, ["scope"] = "openid profile email"
        };
        var req = new HttpRequestMessage(HttpMethod.Post, TokenUrl)
        { Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json") };
        return MakeToken(await PostJsonAsync(req), token.RefreshToken, token.AccountId);
    }

    private static async Task<OAuthTokenResponse> PostJsonAsync(HttpRequestMessage req)
    {
        req.Headers.TryAddWithoutValidation("Accept", "application/json");
        byte[] bytes = await Http.PostAsync(req);
        return JsonSerializer.Deserialize<OAuthTokenResponse>(bytes) ?? throw ProviderException.Decoding("token response");
    }

    private static OAuthToken MakeToken(OAuthTokenResponse r, string? previousRefresh, string? previousAccount)
    {
        var claims = CodexClaims.Decode(r.IdToken ?? r.AccessToken);
        return new OAuthToken(
            r.AccessToken,
            r.RefreshToken ?? previousRefresh,
            DateTimeOffset.UtcNow.AddSeconds(r.ExpiresIn ?? 3600),
            claims.AccountId ?? previousAccount,
            claims.PlanType);
    }
}
