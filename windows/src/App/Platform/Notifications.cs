namespace LLMUsageWidget.App.Platform;

/// <summary>Posts a native Windows toast (Action Center) for near-limit alerts. No-op off Windows so
/// the app still builds and runs cross-platform.</summary>
public static class Notifications
{
    public static void Show(string title, string body)
    {
#if WINDOWS
        try
        {
            new Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder()
                .AddText(title)
                .AddText(body)
                .Show();
        }
        catch { /* best-effort — toast is non-critical */ }
#endif
    }
}
