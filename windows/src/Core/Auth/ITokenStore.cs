using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.Core.Auth;

/// <summary>Per-provider OAuth credential storage. The Windows implementation encrypts with DPAPI.</summary>
public interface ITokenStore
{
    OAuthToken? Get(ProviderId id);
    void Save(ProviderId id, OAuthToken token);
    void Clear(ProviderId id);
}
