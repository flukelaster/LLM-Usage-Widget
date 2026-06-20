using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.Core.Engine;

/// <summary>Decides when a provider's window crosses the high-usage threshold, once per window per
/// reset cycle (no spamming). De-dup is keyed on the window's reset time, so it fires again after the
/// window rolls over. The actual toast is posted by the UI layer.</summary>
public sealed class UsageNotifier
{
    public const double Threshold = 0.90;

    private readonly Dictionary<(ProviderId Provider, LimitWindowKind Kind), DateTimeOffset> _notified = new();

    /// <summary>Pure decision step (also updates dedup state): which windows should fire now.</summary>
    public IReadOnlyList<LimitWindow> WindowsToNotify(ProviderId provider, ProviderUsage usage)
    {
        var firing = new List<LimitWindow>();
        foreach (var window in usage.Windows)
        {
            if (!window.Kind.IsHero()) continue;
            var key = (provider, window.Kind);

            if (window.ClampedUtilization >= Threshold)
            {
                DateTimeOffset marker = window.ResetsAt ?? DateTimeOffset.MaxValue;
                if (!_notified.TryGetValue(key, out var previous) || previous != marker)
                {
                    _notified[key] = marker;
                    firing.Add(window);
                }
            }
            else
            {
                _notified.Remove(key);  // back under threshold → allow a future alert
            }
        }
        return firing;
    }

    public void Clear() => _notified.Clear();
}
