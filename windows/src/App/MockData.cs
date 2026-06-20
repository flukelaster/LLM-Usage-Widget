using LLMUsageWidget.App.ViewModels;
using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.App;

/// <summary>Canned data mirroring the macOS snapshot, used for the design preview / --snapshot and
/// as a placeholder before the engine has fetched real usage.</summary>
public static class MockData
{
    public static PopoverViewModel Popover()
    {
        var now = DateTimeOffset.Now;
        var vm = new PopoverViewModel { Updated = "updated just now" };
        vm.Cards.Add(ProviderCardViewModel.From(Claude(now), now));
        vm.Cards.Add(ProviderCardViewModel.From(Codex(now), now));
        vm.Cards.Add(ProviderCardViewModel.From(Copilot(now), now));
        return vm;
    }

    private static ProviderUsage Claude(DateTimeOffset now) => new(ProviderId.Claude, new[]
    {
        new LimitWindow(LimitWindowKind.FiveHour, 0.47, now.AddHours(2).AddMinutes(13)),
        new LimitWindow(LimitWindowKind.Weekly, 0.63, now.AddDays(2)),
    }, PlanInfo.From("max"));

    private static ProviderUsage Codex(DateTimeOffset now) => new(ProviderId.Codex, new[]
    {
        new LimitWindow(LimitWindowKind.FiveHour, 0.88, now.AddMinutes(47)),
        new LimitWindow(LimitWindowKind.Weekly, 0.93, now.AddDays(3)),
    }, PlanInfo.From("pro"));

    private static ProviderUsage Copilot(DateTimeOffset now) => new(ProviderId.Copilot, new[]
    {
        new LimitWindow(LimitWindowKind.Monthly, 0.12, now.AddDays(5), "Premium requests", Used: 173, Limit: 1500),
    }, PlanInfo.From("individual_pro_plus"));
}
