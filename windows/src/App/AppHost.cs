using System.Diagnostics;
using Avalonia.Threading;
using LLMUsageWidget.App.Platform;
using LLMUsageWidget.App.ViewModels;
using LLMUsageWidget.App.Views;
using LLMUsageWidget.Core.Auth;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Engine;
using LLMUsageWidget.Core.Providers;
using LLMUsageWidget.Core.Settings;
using LLMUsageWidget.Core.Support;

namespace LLMUsageWidget.App;

/// <summary>Wires the engine to the UI: builds providers + token store + <see cref="UsageStore"/>,
/// polls per provider (honoring settings), posts near-limit toasts, and rebuilds the popover
/// view-model on the UI thread. Owns the Settings window and the sign-in flows.</summary>
public sealed class AppHost
{
    public UsageStore Store { get; }
    public SettingsModel Settings { get; }
    public PopoverViewModel Popover { get; } = new();

    /// <summary>Raised on the UI thread after the popover rebuilds (App updates the tray tooltip).</summary>
    public event Action? Updated;

    private readonly UsageNotifier _notifier = new();
    private SettingsWindow? _settingsWindow;

    public AppHost()
    {
        Settings = SettingsModel.Load();
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

    public void Start()
    {
        foreach (var p in Store.Providers)
            _ = PollLoopAsync(p.Id);
    }

    private async Task PollLoopAsync(ProviderId id)
    {
        while (true)
        {
            if (Settings.IsEnabled(id))
            {
                try
                {
                    await Store.RefreshAsync(id);
                    MaybeNotify(id);
                }
                catch { /* state captures the error */ }
            }
            double delay = Store.NextDelaySeconds(id, Settings.PollIntervalSeconds);
            await Task.Delay(TimeSpan.FromSeconds(delay));
        }
    }

    private void MaybeNotify(ProviderId id)
    {
        if (!Settings.NotificationsEnabled) return;
        var provider = Store.Providers.FirstOrDefault(p => p.Id == id);
        var usage = Store.State(id).Usage;
        if (provider is null || usage is null) return;

        foreach (var w in _notifier.WindowsToNotify(id, usage))
        {
            Notifications.Show(
                $"{provider.DisplayName} usage at {w.Percent}%",
                $"Your {w.DisplayTitle} limit is almost used up — {RelativeTime.ResetLabel(w.ResetsAt, DateTimeOffset.Now)}.");
        }
    }

    public Task RefreshNowAsync() => Store.RefreshAllAsync();

    public void ApplySettings() => Dispatcher.UIThread.Post(Rebuild);

    private void Rebuild()
    {
        Popover.Cards.Clear();
        var now = DateTimeOffset.Now;
        DateTimeOffset? newest = null;
        foreach (var p in Store.Providers)
        {
            if (!Settings.IsEnabled(p.Id)) continue;
            var state = Store.State(p.Id);
            Popover.Cards.Add(ProviderCardViewModel.FromState(p, state, now));
            if (state.LastUpdated is { } lu && (newest is null || lu > newest)) newest = lu;
        }
        Popover.Updated = newest is { } n ? RelativeTime.UpdatedAgo(n, now) : "no data yet";
        Updated?.Invoke();
    }

    /// <summary>Short tray tooltip: the focused provider + its %, honoring the menu-bar focus setting.</summary>
    public string MenuBarText()
    {
        var focus = ResolveFocus();
        if (focus is null) return "LLM Usage";
        var (name, _) = Theming.Palette.Meta(focus.Value.Id);
        return $"LLM Usage — {name} {(int)Math.Round(focus.Value.Fraction * 100)}%";
    }

    private (ProviderId Id, double Fraction)? ResolveFocus()
    {
        if (Settings.MenuBarProvider is { } pinned)
        {
            var id = new ProviderId(pinned);
            if (Settings.IsEnabled(id) && Store.State(id).Usage is { } u) return (id, u.MaxUtilization);
        }
        return Store.Peak();
    }

    public void OpenSettings() => Dispatcher.UIThread.Post(() =>
    {
        if (_settingsWindow is null)
        {
            _settingsWindow = new SettingsWindow { DataContext = new SettingsViewModel(Settings, ApplySettings) };
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        }
        _settingsWindow.Show();
        _settingsWindow.Activate();
    });

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
