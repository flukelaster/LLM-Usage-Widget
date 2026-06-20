namespace LLMUsageWidget.Core.Domain;

public enum ThresholdLevel { Safe, Warn, High }

/// <summary>Usage-threshold logic, shared by the UI (which maps levels to colors):
/// green below 60%, amber 60–85%, red above 85%.</summary>
public static class UsageThreshold
{
    public static ThresholdLevel Level(double fraction) => fraction switch
    {
        < 0.60 => ThresholdLevel.Safe,
        < 0.85 => ThresholdLevel.Warn,
        _ => ThresholdLevel.High
    };
}
