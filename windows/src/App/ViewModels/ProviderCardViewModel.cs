using System.Collections.ObjectModel;
using Avalonia.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using LLMUsageWidget.App.Theming;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Engine;
using LLMUsageWidget.Core.Providers;

namespace LLMUsageWidget.App.ViewModels;

/// <summary>One provider card: brand accent, name, plan badge, status pill, and its hero windows.</summary>
public partial class ProviderCardViewModel : ObservableObject
{
    [ObservableProperty] private string _name = "";
    [ObservableProperty] private IBrush _accent = Palette.TextSecondary;
    [ObservableProperty] [NotifyPropertyChangedFor(nameof(HasPlan))] private string? _plan;
    [ObservableProperty] private string _status = "Up to date";
    [ObservableProperty] private IBrush _statusBrush = Palette.Safe;

    public bool HasPlan => !string.IsNullOrEmpty(Plan);
    public Geometry? Logo { get; set; }
    public ObservableCollection<WindowRowViewModel> Windows { get; } = new();

    public static ProviderCardViewModel From(ProviderUsage usage, DateTimeOffset now)
    {
        var (name, accent) = Palette.Meta(usage.ProviderId);
        var vm = new ProviderCardViewModel
        {
            Name = name, Accent = accent, Plan = usage.Plan?.DisplayName, Logo = BrandLogo.For(usage.ProviderId),
        };
        foreach (var w in usage.HeroWindows)
            vm.Windows.Add(WindowRowViewModel.From(w, now));
        return vm;
    }

    /// <summary>Build a card from live engine state — including signed-out / loading / error states.</summary>
    public static ProviderCardViewModel FromState(IUsageProvider provider, UsageStore.ProviderState state, DateTimeOffset now)
    {
        var (name, accent) = Palette.Meta(provider.Id);
        var vm = new ProviderCardViewModel
        {
            Name = name, Accent = accent, Plan = state.Usage?.Plan?.DisplayName, Logo = BrandLogo.For(provider.Id),
        };
        (vm.Status, vm.StatusBrush) = StatusFor(state);
        if (state.Usage is { } usage)
            foreach (var w in usage.HeroWindows)
                vm.Windows.Add(WindowRowViewModel.From(w, now));
        return vm;
    }

    private static (string Text, IBrush Brush) StatusFor(UsageStore.ProviderState s)
    {
        if (s.Auth == ProviderAuthState.SignedOut) return ("Signed out", Palette.TextTertiary);
        if (s.Error is { } e)
            return e.Kind == ProviderErrorKind.RateLimited ? ("Rate-limited", Palette.Warn) : ("Stale", Palette.Warn);
        if (s.Usage is null) return ("Loading…", Palette.TextSecondary);
        return ("Up to date", Palette.Safe);
    }
}
