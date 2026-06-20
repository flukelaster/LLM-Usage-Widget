using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Providers;

namespace LLMUsageWidget.Core.Engine;

/// <summary>Holds per-provider usage state and refreshes it on a cadence, applying exponential
/// backoff on rate limits and keeping the last-good snapshot so the UI never blanks out. Raises
/// <see cref="Changed"/> after any state update (marshal to the UI thread in the handler).</summary>
public sealed class UsageStore
{
    public sealed record ProviderState(
        ProviderUsage? Usage = null,
        ProviderAuthState Auth = ProviderAuthState.SignedOut,
        DateTimeOffset? LastUpdated = null,
        ProviderException? Error = null);

    private readonly Dictionary<ProviderId, ProviderState> _states = new();
    private readonly Dictionary<ProviderId, BackoffPolicy> _backoff = new();
    private readonly object _gate = new();

    public IReadOnlyList<IUsageProvider> Providers { get; }
    public event Action? Changed;

    public UsageStore(IReadOnlyList<IUsageProvider> providers) => Providers = providers;

    public ProviderState State(ProviderId id)
    {
        lock (_gate) return _states.TryGetValue(id, out var s) ? s : new ProviderState();
    }

    /// <summary>Highest utilization across providers with data — drives the menu-bar headline number.</summary>
    public (ProviderId Id, double Fraction)? Peak()
    {
        lock (_gate)
        {
            (ProviderId, double)? best = null;
            foreach (var (id, s) in _states)
                if (s.Usage is { } u && (best is null || u.MaxUtilization > best.Value.Item2))
                    best = (id, u.MaxUtilization);
            return best;
        }
    }

    public async Task RefreshAllAsync() =>
        await Task.WhenAll(Providers.Select(p => RefreshAsync(p.Id)));

    public async Task RefreshAsync(ProviderId id)
    {
        var provider = Providers.FirstOrDefault(p => p.Id == id);
        if (provider is null) return;

        var auth = await provider.AuthStateAsync();
        if (auth != ProviderAuthState.SignedIn)
        {
            Update(id, s => s with { Auth = auth });
            return;
        }

        try
        {
            var usage = await provider.FetchUsageAsync();
            lock (_gate) { _backoff.Remove(id); }
            Update(id, _ => new ProviderState(usage, ProviderAuthState.SignedIn, DateTimeOffset.Now, null));
        }
        catch (ProviderException ex)
        {
            // Keep the last-good usage; just record the error (and auth flip on 401).
            var newAuth = ex.Kind is ProviderErrorKind.Unauthorized or ProviderErrorKind.NotSignedIn
                ? ProviderAuthState.SignedOut
                : ProviderAuthState.SignedIn;
            Update(id, s => s with { Auth = newAuth, Error = ex });
        }
    }

    /// <summary>Seconds to wait before polling <paramref name="id"/> again, honoring backoff/floors.</summary>
    public double NextDelaySeconds(ProviderId id, int globalIntervalSeconds)
    {
        var provider = Providers.FirstOrDefault(p => p.Id == id);
        double floor = provider?.MinimumPollInterval.TotalSeconds ?? 60;
        lock (_gate)
        {
            if (_states.TryGetValue(id, out var s) && s.Error?.Kind == ProviderErrorKind.RateLimited)
            {
                var policy = _backoff.TryGetValue(id, out var p) ? p : (_backoff[id] = new BackoffPolicy());
                return policy.NextDelaySeconds(s.Error.RetryAfter?.TotalSeconds);
            }
        }
        return Math.Max(globalIntervalSeconds, floor);
    }

    private void Update(ProviderId id, Func<ProviderState, ProviderState> mutate)
    {
        lock (_gate)
        {
            var current = _states.TryGetValue(id, out var s) ? s : new ProviderState();
            _states[id] = mutate(current);
        }
        Changed?.Invoke();
    }
}
