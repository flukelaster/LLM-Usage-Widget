using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.Core.Providers;

public enum ProviderAuthState { SignedOut, SignedIn }

/// <summary>How a sign-in flow proceeds after it begins. Providers differ: Codex completes via a
/// loopback redirect, Claude needs a pasted code, Copilot uses the device flow.</summary>
public abstract record SignInFlow
{
    /// <summary>Finished inside StartSignInAsync (e.g. Codex loopback captured the code).</summary>
    public sealed record Completed : SignInFlow;

    /// <summary>The browser shows a code the user must paste back; call <c>Submit</c> to finish.</summary>
    public sealed record NeedsCode(string Instructions, Func<string, Task> Submit) : SignInFlow;

    /// <summary>Device flow: show <c>UserCode</c> for the user to enter at <c>VerificationUrl</c>,
    /// then await <c>Poll</c> (resolves once the user authorizes).</summary>
    public sealed record DeviceCode(string UserCode, Uri VerificationUrl, string Instructions, Func<Task> Poll) : SignInFlow;
}

/// <summary>Everything the app needs from a provider: identity, presentation, auth, and a usage fetch.</summary>
public interface IUsageProvider
{
    ProviderId Id { get; }
    string DisplayName { get; }
    string AccentHex { get; }
    TimeSpan DefaultPollInterval { get; }
    TimeSpan MinimumPollInterval { get; }

    Task<ProviderAuthState> AuthStateAsync();
    Task<SignInFlow> StartSignInAsync();
    Task SignOutAsync();
    Task<ProviderUsage> FetchUsageAsync();
}
