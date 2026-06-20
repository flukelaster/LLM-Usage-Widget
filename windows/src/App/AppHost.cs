using System.Diagnostics;
using Avalonia.Threading;
using LLMUsageWidget.App.ViewModels;
using LLMUsageWidget.App.Views;
using LLMUsageWidget.Core.Auth;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Engine;
using LLMUsageWidget.Core.Providers;
using LLMUsageWidget.Core.Support;

namespace LLMUsageWidget.App;

/// <summary>Wires the engine to the UI: builds the providers + token store + <see cref="UsageStore"/>,
/// runs a per-provider poll loop, and rebuilds the popover view-model on the UI thread when state changes.</summary>
public sealed class AppHost
{
    public UsageStore Store { get; }
    public PopoverViewModel Popover { get; } = new();

    public AppHost()
    {
        var tokens = FileTokenStore.Default();
        Action<Uri> open = OpenBrowser;
        var providers = new IUsageProvider[]
        {
            new ClaudeProvider(tokens, open),
            new CodexProvider(tokens, open),
            new CopilotProvider(tokens, open),
        };
        Store = new UsageStore(providers);
        Store.Changed += () => Dispatcher.UIThread.Post(Rebuild);
        Rebuild();
    }

    public void Start(int intervalSeconds = 300)
    {
        foreach (var p in Store.Providers)
            _ = PollLoopAsync(p.Id, intervalSeconds);
    }

    private async Task PollLoopAsync(ProviderId id, int intervalSeconds)
    {
        while (true)
        {
            try { await Store.RefreshAsync(id); } catch { /* state captures the error */ }
            double delay = Store.NextDelaySeconds(id, intervalSeconds);
            await Task.Delay(TimeSpan.FromSeconds(delay));
        }
    }

    public Task RefreshNowAsync() => Store.RefreshAllAsync();

    private void Rebuild()
    {
        Popover.Cards.Clear();
        var now = DateTimeOffset.Now;
        DateTimeOffset? newest = null;
        foreach (var p in Store.Providers)
        {
            var state = Store.State(p.Id);
            Popover.Cards.Add(ProviderCardViewModel.FromState(p, state, now));
            if (state.LastUpdated is { } lu && (newest is null || lu > newest)) newest = lu;
        }
        Popover.Updated = newest is { } n ? RelativeTime.UpdatedAgo(n, now) : "no data yet";
    }

    public async Task SignInAsync(ProviderId id)
    {
        var provider = Store.Providers.FirstOrDefault(p => p.Id == id);
        if (provider is null) return;
        try
        {
            var flow = await provider.StartSignInAsync();
            switch (flow)
            {
                case SignInFlow.NeedsCode nc:
                    var code = await SignInWindow.PromptCodeAsync(provider.DisplayName, nc.Instructions);
                    if (!string.IsNullOrWhiteSpace(code)) await nc.Submit(code);
                    break;
                case SignInFlow.DeviceCode dc:
                    var win = SignInWindow.ShowDevice(provider.DisplayName, dc.UserCode, dc.VerificationUrl, dc.Instructions);
                    try { await dc.Poll(); }
                    finally { win.CloseFromHost(); }
                    break;
                case SignInFlow.Completed:
                    break;
            }
            await Store.RefreshAsync(id);
        }
        catch
        {
            // Errors surface through provider state on the next refresh.
        }
    }

    public async Task SignOutAsync(ProviderId id)
    {
        var provider = Store.Providers.FirstOrDefault(p => p.Id == id);
        if (provider is null) return;
        await provider.SignOutAsync();
        await Store.RefreshAsync(id);
    }

    private static void OpenBrowser(Uri url)
    {
        try { Process.Start(new ProcessStartInfo(url.ToString()) { UseShellExecute = true }); }
        catch { /* best-effort */ }
    }
}
