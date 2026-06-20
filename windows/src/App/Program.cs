using Avalonia;

namespace LLMUsageWidget.App;

internal static class Program
{
    // Initialization code. Don't use any Avalonia, third-party APIs or any SynchronizationContext-
    // reliant code before AppMain is called: things aren't initialized yet and stuff might break.
    [STAThread]
    public static int Main(string[] args)
    {
        // Headless render path: `LLMUsageWidget.App --snapshot out.png` (mirrors the macOS app).
        if (args.Length >= 2 && args[0] == "--snapshot")
            return Snapshot.Run(args[1]);

        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
        return 0;
    }

    // Avalonia configuration, don't remove; also used by the visual designer.
    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace();
}
