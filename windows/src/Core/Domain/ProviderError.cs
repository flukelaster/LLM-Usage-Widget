namespace LLMUsageWidget.Core.Domain;

/// <summary>Errors a provider can surface. The engine maps these into per-provider UI states.</summary>
public enum ProviderErrorKind
{
    /// <summary>No stored credentials — the card should prompt sign-in.</summary>
    NotSignedIn,
    /// <summary>Token rejected (401). The provider tries one refresh+retry before throwing this.</summary>
    Unauthorized,
    /// <summary>429. <c>RetryAfter</c> is honored when the server provides it; otherwise the engine backs off.</summary>
    RateLimited,
    /// <summary>Network/transport failure (offline, DNS, TLS, timeouts).</summary>
    Transport,
    /// <summary>Response could not be decoded into the expected shape.</summary>
    Decoding
}

public sealed class ProviderException : Exception
{
    public ProviderErrorKind Kind { get; }
    public TimeSpan? RetryAfter { get; }

    public ProviderException(ProviderErrorKind kind, string? message = null, TimeSpan? retryAfter = null)
        : base(message ?? kind.ToString())
    {
        Kind = kind;
        RetryAfter = retryAfter;
    }

    public static ProviderException NotSignedIn() => new(ProviderErrorKind.NotSignedIn);
    public static ProviderException Unauthorized() => new(ProviderErrorKind.Unauthorized);
    public static ProviderException RateLimited(TimeSpan? retryAfter) => new(ProviderErrorKind.RateLimited, "rate limited", retryAfter);
    public static ProviderException Transport(string message) => new(ProviderErrorKind.Transport, message);
    public static ProviderException Decoding(string message) => new(ProviderErrorKind.Decoding, message);
}
