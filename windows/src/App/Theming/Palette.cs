using Avalonia.Media;
using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.App.Theming;

/// <summary>Design tokens ported from the macOS app (Views/DesignTokens.swift): dark-mode-first,
/// the same threshold hues, and per-provider brand accents.</summary>
public static class Palette
{
    public static readonly IBrush Safe = Hex("#32D74B");          // < 60%
    public static readonly IBrush Warn = Hex("#FF9F0A");          // 60–85%
    public static readonly IBrush High = Hex("#FF453A");          // > 85%
    public static readonly IBrush TextPrimary = Hex("#F8FAFC");
    public static readonly IBrush TextSecondary = Hex("#94A3B8");
    public static readonly IBrush TextTertiary = Hex("#64748B");
    public static readonly IBrush Track = Hex("#FFFFFF", 0.10);

    public static SolidColorBrush Hex(string hex, double opacity = 1)
    {
        var c = Color.Parse(hex);
        return new SolidColorBrush(Color.FromArgb((byte)(opacity * 255), c.R, c.G, c.B));
    }

    /// <summary>Color for a normalized utilization 0..1.</summary>
    public static IBrush Threshold(double fraction) =>
        fraction < 0.60 ? Safe : fraction < 0.85 ? Warn : High;

    public static (string Name, IBrush Accent) Meta(ProviderId id)
    {
        if (id == ProviderId.Claude) return ("Claude", Hex("#D97757"));
        if (id == ProviderId.Codex) return ("Codex", Hex("#10A37F"));
        if (id == ProviderId.Copilot) return ("Copilot", Hex("#8957E5"));
        return (id.RawValue, TextSecondary);
    }
}
