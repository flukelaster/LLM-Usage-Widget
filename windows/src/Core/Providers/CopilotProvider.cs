using LLMUsageWidget.Core.Auth;
using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.Core.Providers;

/// <summary>GitHub Copilot provider: device-flow OAuth, token refresh, and monthly-quota fetch.</summary>
public sealed class CopilotProvider : IUsageProvider
{
    public ProviderId Id => ProviderId.Copilot;
    public string DisplayName => "Copilot";
    public string AccentHex => "#8957E5";
    public TimeSpan DefaultPollInterval => TimeSpan.FromSeconds(600);  // monthly quota moves slowly
    public TimeSpan MinimumPollInterval => TimeSpan.FromSeconds(120);

    private readonly ITokenStore _tokens;
    private readonly Action<Uri> _openBrowser;
    private readonly CopilotOAuthClient _oauth = new();
    private readonly CopilotUsageFetcher _fetcher = new();

    public CopilotProvider(ITokenStore tokens, Action<Uri> openBrowser)
    {
        _tokens = tokens;
        _openBrowser = openBrowser;
    }

    public Task<ProviderAuthState> AuthStateAsync() =>
        Task.FromResult(_tokens.Get(Id) is not null ? ProviderAuthState.SignedIn : ProviderAuthState.SignedOut);

    public async Task<SignInFlow> StartSignInAsync()
    {
        var device = await _oauth.RequestDeviceCodeAsync();
        var url = Uri.TryCreate(device.VerificationUri, UriKind.Absolute, out var u) ? u : new Uri("https://github.com/login/device");
        _openBrowser(url);
        Func<Task> poll = async () =>
        {
            var token = await _oauth.PollForTokenAsync(device.DeviceCode, device.Interval, device.ExpiresIn);
            _tokens.Save(Id, token);
        };
        return new SignInFlow.DeviceCode(device.UserCode, url,
            "Enter this code at github.com/login/device to connect Copilot.", poll);
    }

    public Task SignOutAsync()
    {
        _tokens.Clear(Id);
        return Task.CompletedTask;
    }

    public async Task<ProviderUsage> FetchUsageAsync()
    {
        var token = _tokens.Get(Id) ?? throw ProviderException.NotSignedIn();
        if (token.NeedsRefresh() && token.RefreshToken is not null)
        {
            try { token = await RefreshAndStoreAsync(token); }
            catch (ProviderException) { /* keep current token; the fetch below will decide */ }
        }
        try
        {
            return await _fetcher.FetchAsync(token.AccessToken);
        }
        catch (ProviderException ex) when (ex.Kind == ProviderErrorKind.Unauthorized)
        {
            if (token.RefreshToken is not null)
            {
                var refreshed = await RefreshAndStoreAsync(token);
                return await _fetcher.FetchAsync(refreshed.AccessToken);
            }
            _tokens.Clear(Id);  // non-expiring token was revoked → require re-auth
            throw;
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
