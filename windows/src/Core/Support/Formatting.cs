using System.Globalization;

namespace LLMUsageWidget.Core.Support;

/// <summary>Relative-time formatting for reset countdowns and "updated X ago" labels.</summary>
public static class RelativeTime
{
    /// <summary>Compact duration like "2h 14m", "5m", "3d 4h", "now".</summary>
    public static string Countdown(DateTimeOffset date, DateTimeOffset now)
    {
        int total = Math.Max(0, (int)(date - now).TotalSeconds);
        if (total < 60) return "now";
        int minutes = total / 60;
        int hours = minutes / 60;
        int days = hours / 24;
        if (days >= 1)
        {
            int h = hours % 24;
            return h > 0 ? $"{days}d {h}h" : $"{days}d";
        }
        if (hours >= 1)
        {
            int m = minutes % 60;
            return m > 0 ? $"{hours}h {m}m" : $"{hours}h";
        }
        return $"{minutes}m";
    }

    /// <summary>"resets in 2h 14m" for near windows; absolute "resets Tue 9:00 AM" for far ones.</summary>
    public static string ResetLabel(DateTimeOffset? date, DateTimeOffset now)
    {
        if (date is not DateTimeOffset d) return "no reset info";
        double interval = (d - now).TotalSeconds;
        if (interval <= 0) return "resetting now";
        if (interval < 12 * 3600) return $"resets in {Countdown(d, now)}";
        return "resets " + d.ToLocalTime().ToString("ddd h:mm tt", CultureInfo.InvariantCulture);
    }

    /// <summary>"updated just now", "updated 3m ago", "updated 2h ago".</summary>
    public static string UpdatedAgo(DateTimeOffset? date, DateTimeOffset now)
    {
        if (date is not DateTimeOffset d) return "never updated";
        int secs = Math.Max(0, (int)(now - d).TotalSeconds);
        if (secs < 10) return "updated just now";
        if (secs < 60) return $"updated {secs}s ago";
        int minutes = secs / 60;
        if (minutes < 60) return $"updated {minutes}m ago";
        int hours = minutes / 60;
        if (hours < 24) return $"updated {hours}h ago";
        return $"updated {hours / 24}d ago";
    }
}

/// <summary>Large-number formatting for token / quota counts: 1284000 -> "1.28M".</summary>
public static class NumberFormat
{
    public static string Compact(int value)
    {
        double v = value;
        double a = Math.Abs(v);
        if (a >= 1_000_000_000) return string.Format(CultureInfo.InvariantCulture, "{0:0.00}B", v / 1_000_000_000);
        if (a >= 1_000_000) return string.Format(CultureInfo.InvariantCulture, "{0:0.00}M", v / 1_000_000);
        if (a >= 1_000) return string.Format(CultureInfo.InvariantCulture, "{0:0.0}K", v / 1_000);
        return value.ToString(CultureInfo.InvariantCulture);
    }

    public static string Currency(double value) =>
        string.Format(CultureInfo.InvariantCulture, "${0:0.00}", value);
}
