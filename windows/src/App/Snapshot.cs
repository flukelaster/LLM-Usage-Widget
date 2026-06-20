using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless;
using Avalonia.Threading;
using LLMUsageWidget.App.Views;

namespace LLMUsageWidget.App;

/// <summary>Renders the popover to a PNG using the headless + Skia platform — the cross-platform
/// equivalent of the macOS app's <c>--snapshot</c>, so the UI can be verified on any OS (no real
/// windowing system or run loop required).</summary>
public static class Snapshot
{
    public static int Run(string path)
    {
        try
        {
            AppBuilder.Configure<App>()
                .UseSkia()
                .UseHeadless(new AvaloniaHeadlessPlatformOptions { UseHeadlessDrawing = false })
                .WithInterFont()
                .SetupWithoutStarting();

            return Dispatcher.UIThread.Invoke(() =>
            {
                var view = new PopoverView { DataContext = MockData.Popover() };
                var window = new Window
                {
                    Content = view,
                    SizeToContent = SizeToContent.WidthAndHeight,
                    ShowInTaskbar = false,
                };
                window.Show();
                Dispatcher.UIThread.RunJobs();

                var frame = window.CaptureRenderedFrame();
                if (frame is null)
                {
                    Console.Error.WriteLine("snapshot: no frame captured");
                    return 1;
                }
                frame.Save(path);
                Console.WriteLine($"snapshot: wrote {path} ({frame.PixelSize.Width}x{frame.PixelSize.Height})");
                return 0;
            });
        }
        catch (Exception e)
        {
            Console.Error.WriteLine("snapshot failed: " + e);
            return 1;
        }
    }
}
