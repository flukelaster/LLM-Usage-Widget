namespace LLMUsageWidget.Core.Engine;

/// <summary>Exponential backoff with jitter, for endpoints that rate-limit aggressively — notably
/// Claude's usage API, which often returns 429 with no Retry-After. When the server does provide a
/// delay, we honor it; otherwise we grow the delay geometrically up to a cap. Delays in seconds.</summary>
public sealed class BackoffPolicy
{
    private readonly double _baseSeconds;
    private readonly double _maxSeconds;

    public int Attempt { get; private set; }

    public BackoffPolicy(double baseSeconds = 60, double maxSeconds = 30 * 60)
    {
        _baseSeconds = baseSeconds;
        _maxSeconds = maxSeconds;
    }

    public bool IsBackingOff => Attempt > 0;

    /// <summary>Advance the attempt counter and return the delay before the next try.</summary>
    public double NextDelaySeconds(double? retryAfter)
    {
        Attempt++;
        if (retryAfter is double ra && ra > 0)
            return Math.Min(ra, _maxSeconds);

        double exp = _baseSeconds * Math.Pow(2, Attempt - 1);
        double capped = Math.Min(exp, _maxSeconds);
        double jitter = Random.Shared.NextDouble() * (capped * 0.25);
        return Math.Min(capped + jitter, _maxSeconds);
    }

    public void Reset() => Attempt = 0;
}
