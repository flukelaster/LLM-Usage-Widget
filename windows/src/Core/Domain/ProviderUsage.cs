namespace LLMUsageWidget.Core.Domain;

/// <summary>A single snapshot of a provider's usage. The unified currency the whole app speaks in.</summary>
public sealed record ProviderUsage(
    ProviderId ProviderId,
    IReadOnlyList<LimitWindow> Windows,
    PlanInfo? Plan = null,
    TokenStats? Tokens = null,
    DateTimeOffset? CapturedAt = null)
{
    /// <summary>The windows that drive the hero view, ordered (5-hour first).</summary>
    public IReadOnlyList<LimitWindow> HeroWindows =>
        Windows.Where(w => w.Kind.IsHero()).OrderBy(w => w.Kind.SortIndex()).ToList();

    /// <summary>Non-hero windows (e.g. per-model weekly breakdowns) shown under "Details".</summary>
    public IReadOnlyList<LimitWindow> DetailWindows =>
        Windows.Where(w => !w.Kind.IsHero()).OrderBy(w => w.Kind.SortIndex()).ToList();

    public LimitWindow? FiveHour => Windows.FirstOrDefault(w => w.Kind == LimitWindowKind.FiveHour);
    public LimitWindow? Weekly => Windows.FirstOrDefault(w => w.Kind == LimitWindowKind.Weekly);

    /// <summary>Highest utilization across all windows — feeds the menu-bar headline percentage.</summary>
    public double MaxUtilization => Windows.Count == 0 ? 0 : Windows.Max(w => w.ClampedUtilization);
}
