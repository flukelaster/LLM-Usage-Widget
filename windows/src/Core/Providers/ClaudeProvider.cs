using LLMUsageWidget.Core.Auth;
using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.Core.Providers;

/// <summary>Claude provider: paste-code OAuth, token refresh, and usage fetch. The plan badge is
/// fetched once from the profile endpoint and cached on the token.</summary>
public sealed class ClaudeProvider : IUsageProvider
{
    public ProviderId Id => ProviderId.Claude;
    public string DisplayName => "Claude";
    public string AccentHex => "#D97757";
    public TimeSpan DefaultPollInterval => TimeSpan.FromSeconds(300);
    public TimeSpan MinimumPollInterval => TimeSpan.FromSeconds(300);

    private readonly ITokenStore _tokens;
    private readonly Action<Uri> _openBrowser;
    private readonly ClaudeOAuthClient _oauth = new();
    private readonly ClaudeUsageFetcher _fetcher = new();
    private readonly ClaudeProfileFetcher _profile = new();

    public ClaudeProvider(ITokenStore tokens, Action<Uri> openBrowser)
    {
        _tokens = tokens;
        _openBrowser = openBrowser;
    }

    public Task<ProviderAuthState> AuthStateAsync() =>
        Task.FromResult(_tokens.Get(Id) is not null ? ProviderAuthState.SignedIn : ProviderAuthState.SignedOut);

    public Task<SignInFlow> StartSignInAsync()
    {
        var pkce = Pkce.Generate();
        _openBrowser(_oauth.MakeAuthorizeUrl(pkce));
        Func<string, Task> submit = async pasted =>
        {
            var token = await _oauth.ExchangeAsync(pasted, pkce);
            _tokens.Save(Id, token);
        };
        return Task.FromResult<SignInFlow>(new SignInFlow.NeedsCode(
            "Approve access in your browser, then paste the code it shows (looks like \"abc123#xyz\").", submit));
    }

    public Task SignOutAsync()
    {
        _tokens.Clear(Id);
        return Task.CompletedTask;
    }

    public async Task<ProviderUsage> FetchUsageAsync()
    {
        var token = _tokens.Get(Id) ?? throw ProviderException.NotSignedIn();
        if (token.NeedsRefresh()) token = await RefreshAndStoreAsync(token);
        token = await EnsurePlanAsync(token);
        try
        {
            return await _fetcher.FetchAsync(token.AccessToken, token.PlanType);
        }
        catch (ProviderException ex) when (ex.Kind == ProviderErrorKind.Unauthorized)
        {
            var refreshed = await EnsurePlanAsync(await RefreshAndStoreAsync(token));
            return await _fetcher.FetchAsync(refreshed.AccessToken, refreshed.PlanType);
        }
    }

    /// <summary>The usage endpoint carries no plan, so fetch the profile once and cache it. Best-effort.</summary>
    private async Task<OAuthToken> EnsurePlanAsync(OAuthToken token)
    {
        if (token.PlanType is not null) return token;
        try
        {
            string? raw = await _profile.FetchRawPlanAsync(token.AccessToken);
            if (raw is null) return token;
            var updated = token with { PlanType = raw };
            _tokens.Save(Id, updated);
            return updated;
        }
        catch
        {
            return token;
        }
    }

    private async Task<OAuthToken> RefreshAndStoreAsync(OAuthToken token)
    {
        try
        {
            var refreshed = await _oauth.RefreshAsync(token);
            refreshed = refreshed with { PlanType = refreshed.PlanType ?? token.PlanType };  // keep cached plan
            _tokens.Save(Id, refreshed);
            return refreshed;
        }
        catch
        {
            _tokens.Clear(Id);
            throw ProviderException.Unauthorized();
        }
    }
}
