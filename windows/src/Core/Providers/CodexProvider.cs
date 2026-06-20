using LLMUsageWidget.Core.Auth;
using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.Core.Providers;

/// <summary>Codex provider: loopback OAuth (completes inside sign-in), token refresh, and usage fetch.</summary>
public sealed class CodexProvider : IUsageProvider
{
    public ProviderId Id => ProviderId.Codex;
    public string DisplayName => "Codex";
    public string AccentHex => "#10A37F";
    public TimeSpan DefaultPollInterval => TimeSpan.FromSeconds(120);
    public TimeSpan MinimumPollInterval => TimeSpan.FromSeconds(60);

    private readonly ITokenStore _tokens;
    private readonly Action<Uri> _openBrowser;
    private readonly CodexOAuthClient _oauth = new();
    private readonly CodexUsageFetcher _fetcher = new();

    public CodexProvider(ITokenStore tokens, Action<Uri> openBrowser)
    {
        _tokens = tokens;
        _openBrowser = openBrowser;
    }

    public Task<ProviderAuthState> AuthStateAsync() =>
        Task.FromResult(_tokens.Get(Id) is not null ? ProviderAuthState.SignedIn : ProviderAuthState.SignedOut);

    public async Task<SignInFlow> StartSignInAsync()
    {
        var pkce = Pkce.Generate();
        _openBrowser(_oauth.MakeAuthorizeUrl(pkce));
        string code = await LoopbackServer.WaitForCodeAsync(CodexOAuthClient.LoopbackPort, pkce.State, TimeSpan.FromMinutes(5));
        var token = await _oauth.ExchangeAsync(code, pkce);
        _tokens.Save(Id, token);
        return new SignInFlow.Completed();
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
        try
        {
            return await _fetcher.FetchAsync(token.AccessToken, token.AccountId, token.PlanType);
        }
        catch (ProviderException ex) when (ex.Kind == ProviderErrorKind.Unauthorized)
        {
            var refreshed = await RefreshAndStoreAsync(token);
            return await _fetcher.FetchAsync(refreshed.AccessToken, refreshed.AccountId, refreshed.PlanType);
        }
    }

    private async Task<OAuthToken> RefreshAndStoreAsync(OAuthToken token)
    {
        try
        {
            var refreshed = await _oauth.RefreshAsync(token);
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
