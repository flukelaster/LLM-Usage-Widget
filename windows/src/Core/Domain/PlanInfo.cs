using System.Globalization;

namespace LLMUsageWidget.Core.Domain;

/// <summary>Subscription plan info shown as a small badge on each provider card.</summary>
public sealed record PlanInfo(string DisplayName, string? RawValue = null)
{
    /// <summary>Build a nicely-cased plan from a provider's raw <c>plan_type</c> / org type string.</summary>
    public static PlanInfo? From(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        string pretty = raw.ToLowerInvariant() switch
        {
            "free" => "Free",
            "plus" => "Plus",
            "pro" => "Pro",
            "team" => "Team",
            "enterprise" or "ent" => "Enterprise",
            "max" or "max_5x" or "max_20x" or "max5x" or "max20x" or "claude_max" => "Max",
            "claude_pro" => "Pro",
            "claude_free" => "Free",
            "claude_team" => "Team",
            "claude_enterprise" => "Enterprise",
            "individual_pro_plus" or "pro_plus" => "Pro+",
            "individual_pro" => "Pro",
            "individual" => "Individual",
            "business" => "Business",
            _ => CultureInfo.InvariantCulture.TextInfo.ToTitleCase(raw.Replace('_', ' ').ToLowerInvariant())
        };
        return new PlanInfo(pretty, raw);
    }
}
