using Avalonia.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using LLMUsageWidget.App.Theming;
using LLMUsageWidget.Core.Domain;
using LLMUsageWidget.Core.Support;

namespace LLMUsageWidget.App.ViewModels;

/// <summary>One usage window row inside a provider card: title, big %, threshold-colored bar, and
/// a reset label (with an optional raw count for quota-style windows).</summary>
public partial class WindowRowViewModel : ObservableObject
{
    [ObservableProperty] private string _title = "";
    [ObservableProperty] private string _percentText = "";
    [ObservableProperty] private IBrush _percentBrush = Palette.TextPrimary;
    [ObservableProperty] private double _fraction;
    [ObservableProperty] private string _resetText = "";
    [ObservableProperty] private bool _unlimited;

    public IBrush Track => Palette.Track;

    public static WindowRowViewModel From(LimitWindow w, DateTimeOffset now)
    {
        var vm = new WindowRowViewModel { Title = w.DisplayTitle, Unlimited = w.Unlimited };
        if (w.Unlimited)
        {
            vm.PercentText = "Unlimited";
            vm.PercentBrush = Palette.Safe;
            vm.Fraction = 0;
        }
        else
        {
            vm.PercentText = $"{w.Percent}%";
            vm.PercentBrush = Palette.Threshold(w.ClampedUtilization);
            vm.Fraction = w.ClampedUtilization;
        }
        string reset = RelativeTime.ResetLabel(w.ResetsAt, now);
        vm.ResetText = w.CountText is { } count ? $"{reset}  ·  {count}" : reset;
        return vm;
    }
}
