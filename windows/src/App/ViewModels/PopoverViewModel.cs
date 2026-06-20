using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;

namespace LLMUsageWidget.App.ViewModels;

/// <summary>The popover root: a header status line plus one card per enabled provider.</summary>
public partial class PopoverViewModel : ObservableObject
{
    [ObservableProperty] private string _updated = "updated just now";
    public ObservableCollection<ProviderCardViewModel> Cards { get; } = new();
}
