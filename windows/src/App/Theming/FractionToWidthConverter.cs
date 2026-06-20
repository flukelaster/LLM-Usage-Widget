using System.Globalization;
using Avalonia.Data.Converters;

namespace LLMUsageWidget.App.Theming;

/// <summary>Maps a 0..1 utilization to a pixel width for the usage bar's filled portion, given the
/// track width as the converter parameter. Keeps a small minimum nub so non-zero usage is visible.</summary>
public sealed class FractionToWidthConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        double fraction = value is double d ? d : 0;
        double total = parameter is string s && double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out var tw) ? tw : 100;
        if (fraction <= 0) return 0d;
        return Math.Max(fraction * total, 6);
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
