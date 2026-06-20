namespace LLMUsageWidget.Core.Domain;

/// <summary>Optional secondary token/cost detail, shown in the collapsible "Details" section.
/// May be null when a provider doesn't expose token counts through its live endpoint.</summary>
public sealed record TokenStats(
    int? InputTokens = null,
    int? OutputTokens = null,
    int? CacheReadTokens = null,
    int? CacheWriteTokens = null,
    double? EstimatedCostUsd = null,
    DateTimeOffset? Since = null)
{
    /// <summary>Sum of all known token buckets, or null if none are present.</summary>
    public int? TotalTokens
    {
        get
        {
            int[] parts = new[] { InputTokens, OutputTokens, CacheReadTokens, CacheWriteTokens }
                .Where(p => p.HasValue).Select(p => p!.Value).ToArray();
            return parts.Length == 0 ? null : parts.Sum();
        }
    }

    public bool HasAnyValue => TotalTokens != null || EstimatedCostUsd != null;
}
