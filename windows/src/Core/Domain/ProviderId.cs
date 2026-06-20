namespace LLMUsageWidget.Core.Domain;

/// <summary>Stable identifier for a usage provider. Open by design — adding a provider is just a
/// new constant plus a concrete provider implementation.</summary>
public readonly record struct ProviderId(string RawValue)
{
    public static readonly ProviderId Claude = new("claude");
    public static readonly ProviderId Codex = new("codex");
    public static readonly ProviderId Copilot = new("copilot");

    public override string ToString() => RawValue;
}
