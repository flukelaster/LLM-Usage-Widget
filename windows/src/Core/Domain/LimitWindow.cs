using LLMUsageWidget.Core.Support;

namespace LLMUsageWidget.Core.Domain;

public enum LimitWindowKind { FiveHour, Weekly, WeeklyOpus, WeeklySonnet, Monthly }

public static class LimitWindowKindExtensions
{
    /// <summary>Default human-facing title (a window may override via <c>Label</c>).</summary>
    public static string Title(this LimitWindowKind k) => k switch
    {
        LimitWindowKind.FiveHour => "5-hour",
        LimitWindowKind.Weekly => "Weekly",
        LimitWindowKind.WeeklyOpus => "Weekly · Opus",
        LimitWindowKind.WeeklySonnet => "Weekly · Sonnet",
        LimitWindowKind.Monthly => "Monthly",
        _ => k.ToString()
    };

    /// <summary>Windows that make up the hero view. Others fold into "Details".</summary>
    public static bool IsHero(this LimitWindowKind k) =>
        k is LimitWindowKind.FiveHour or LimitWindowKind.Weekly or LimitWindowKind.Monthly;

    public static int SortIndex(this LimitWindowKind k) => k switch
    {
        LimitWindowKind.FiveHour => 0,
        LimitWindowKind.Monthly => 1,
        LimitWindowKind.Weekly => 2,
        LimitWindowKind.WeeklyOpus => 3,
        LimitWindowKind.WeeklySonnet => 4,
        _ => 99
    };
}

/// <summary>A single usage window for a provider, normalized into a common shape. Rolling windows
/// (Claude/Codex 5-hour + weekly) and quota-style windows (Copilot monthly) both use this.</summary>
public sealed record LimitWindow(
    LimitWindowKind Kind,
    double Utilization,
    DateTimeOffset? ResetsAt,
    string? Label = null,
    double? Used = null,
    double? Limit = null,
    bool Unlimited = false)
{
    public string DisplayTitle => Label ?? Kind.Title();

    /// <summary>Utilization clamped to a safe 0..1 for display math.</summary>
    public double ClampedUtilization => Math.Min(Math.Max(Utilization, 0), 1);

    /// <summary>Integer percentage used, e.g. 47.</summary>
    public int Percent => (int)Math.Round(ClampedUtilization * 100, MidpointRounding.AwayFromZero);

    /// <summary>"173 / 1.5K" when raw counts are present.</summary>
    public string? CountText
    {
        get
        {
            if (Used is not double u || Limit is not double l || l <= 0) return null;
            int used = (int)Math.Round(u, MidpointRounding.AwayFromZero);
            int limit = (int)Math.Round(l, MidpointRounding.AwayFromZero);
            return $"{NumberFormat.Compact(used)} / {NumberFormat.Compact(limit)}";
        }
    }
}
