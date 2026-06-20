using System.Collections.ObjectModel;
using Avalonia.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using LLMUsageWidget.App.Theming;
using LLMUsageWidget.Core.Domain;

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
    public ObservableCollection<WindowRowViewModel> Windows { get; } = new();

    public static ProviderCardViewModel From(ProviderUsage usage, DateTimeOffset now)
    {
        var (name, accent) = Palette.Meta(usage.ProviderId);
        var vm = new ProviderCardViewModel { Name = name, Accent = accent, Plan = usage.Plan?.DisplayName };
        foreach (var w in usage.HeroWindows)
            vm.Windows.Add(WindowRowViewModel.From(w, now));
        return vm;
    }
}
