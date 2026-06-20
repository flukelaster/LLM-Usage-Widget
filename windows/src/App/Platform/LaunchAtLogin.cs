namespace LLMUsageWidget.App.Platform;

/// <summary>Launch-at-login via the per-user Run key (Windows). Compiles to no-ops elsewhere so the
/// app still builds on macOS/Linux.</summary>
public static class LaunchAtLogin
{
#if WINDOWS
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "LLMUsageWidget";
#endif

    public static bool IsEnabled
    {
        get
        {
#if WINDOWS
            try
            {
                using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(RunKeyPath);
                return key?.GetValue(ValueName) is not null;
            }
            catch { return false; }
#else
            return false;
#endif
        }
    }

    public static void Set(bool enabled)
    {
#if WINDOWS
        try
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(RunKeyPath);
            if (key is null) return;
            if (enabled)
            {
                string? exe = Environment.ProcessPath;
                if (exe is not null) key.SetValue(ValueName, $"\"{exe}\"");
            }
            else
            {
                key.DeleteValue(ValueName, throwOnMissingValue: false);
            }
        }
        catch { /* best-effort */ }
#endif
    }

    /// <summary>True on platforms where this toggle does anything (Windows).</summary>
    public static bool Supported =>
#if WINDOWS
        true;
#else
        false;
#endif
}
