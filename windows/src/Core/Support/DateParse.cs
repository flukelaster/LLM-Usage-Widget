using System.Globalization;

namespace LLMUsageWidget.Core.Support;

/// <summary>Tolerant date parsing shared by the provider parsers: ISO-8601 (with or without
/// fractional seconds / offset), plain "yyyy-MM-dd", and unix-epoch seconds.</summary>
public static class DateParse
{
    public static DateTimeOffset? Iso(string? s)
    {
        if (string.IsNullOrWhiteSpace(s)) return null;
        if (DateTimeOffset.TryParse(s, CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var dt))
            return dt;
        if (DateTime.TryParseExact(s, "yyyy-MM-dd", CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal, out var d))
            return new DateTimeOffset(d, TimeSpan.Zero);
        return null;
    }

    public static DateTimeOffset FromUnixSeconds(double seconds) =>
        DateTimeOffset.FromUnixTimeMilliseconds((long)(seconds * 1000));
}
