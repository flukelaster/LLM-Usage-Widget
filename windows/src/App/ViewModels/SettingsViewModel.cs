using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using LLMUsageWidget.App.Platform;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Settings;

namespace LLMUsageWidget.App.ViewModels;

/// <summary>One provider's enable/disable toggle in Settings.</summary>
public partial class ProviderToggleViewModel : ObservableObject
{
    private readonly SettingsModel _settings;
    private readonly Action _apply;

    public ProviderId Id { get; }
    public string Name { get; }
    [ObservableProperty] private bool _enabled;

    public ProviderToggleViewModel(SettingsModel settings, Action apply, ProviderId id, string name)
    {
        _settings = settings;
        _apply = apply;
        Id = id;
        Name = name;
        _enabled = settings.IsEnabled(id);
    }

    partial void OnEnabledChanged(bool value)
    {
        _settings.SetEnabled(Id, value);
        _settings.Save();
        _apply();
    }
}

/// <summary>Backs the Settings window. Every change persists immediately and calls <c>apply</c> so the
/// running app picks it up (re-poll cadence, focus, enabled set).</summary>
public partial class SettingsViewModel : ObservableObject
{
    private readonly SettingsModel _settings;
    private readonly Action _apply;

    public string[] FocusOptions { get; } = { "Closest to full", "Claude", "Codex", "Copilot" };
    public string[] DisplayOptions { get; } = { "Provider icon + %", "Gauge + %", "Icon only" };
    public string[] IntervalOptions { get; } = { "1 minute", "2 minutes", "5 minutes", "15 minutes" };

    private static readonly int[] Intervals = { 60, 120, 300, 900 };
    private static readonly string?[] FocusIds = { null, "claude", "codex", "copilot" };

    [ObservableProperty] private int _focusIndex;
    [ObservableProperty] private int _displayIndex;
    [ObservableProperty] private int _intervalIndex;
    [ObservableProperty] private bool _notificationsEnabled;
    [ObservableProperty] private bool _launchAtLogin;

    public bool LaunchSupported => Platform.LaunchAtLogin.Supported;
    public ObservableCollection<ProviderToggleViewModel> Providers { get; } = new();

    public SettingsViewModel(SettingsModel settings, Action apply)
    {
        _settings = settings;
        _apply = apply;
        _focusIndex = Math.Max(0, Array.IndexOf(FocusIds, settings.MenuBarProvider));
        _displayIndex = (int)settings.MenuBarDisplay;
        _intervalIndex = Math.Max(0, Array.IndexOf(Intervals, settings.PollIntervalSeconds));
        _notificationsEnabled = settings.NotificationsEnabled;
        _launchAtLogin = Platform.LaunchAtLogin.IsEnabled;

        Providers.Add(new ProviderToggleViewModel(settings, apply, ProviderId.Claude, "Claude"));
        Providers.Add(new ProviderToggleViewModel(settings, apply, ProviderId.Codex, "Codex"));
        Providers.Add(new ProviderToggleViewModel(settings, apply, ProviderId.Copilot, "Copilot"));
    }

    partial void OnFocusIndexChanged(int value)
    {
        _settings.MenuBarProvider = FocusIds[Math.Clamp(value, 0, FocusIds.Length - 1)];
        _settings.Save();
        _apply();
    }

    partial void OnDisplayIndexChanged(int value)
    {
        _settings.MenuBarDisplay = (MenuBarDisplay)Math.Clamp(value, 0, 2);
        _settings.Save();
        _apply();
    }

    partial void OnIntervalIndexChanged(int value)
    {
        _settings.PollIntervalSeconds = Intervals[Math.Clamp(value, 0, Intervals.Length - 1)];
        _settings.Save();
        _apply();
    }

    partial void OnNotificationsEnabledChanged(bool value)
    {
        _settings.NotificationsEnabled = value;
        _settings.Save();
    }

    partial void OnLaunchAtLoginChanged(bool value) => Platform.LaunchAtLogin.Set(value);
}
